// Archivo: supabase/functions/botlode-brain/index.ts
// ⬅️ VERSIÓN PROFESIONAL MEJORADA - Sistema de IA con extracción inteligente

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

const MODEL_NAME = 'gemini-2.0-flash'; 
const API_VERSION = 'v1beta';
const HISTORY_WINDOW = Number(Deno.env.get('BRAIN_HISTORY_LIMIT') || '60');
const MEMORY_SUMMARY_MAX_CHARS = 1200;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-client-session-id',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// ⬅️ MEJORA 1: Logging optimizado para evitar saturación de BigQuery
// Solo loggea errores y warnings críticos para reducir carga en BigQuery
const LOG_LEVEL = Deno.env.get('LOG_LEVEL') || 'error'; // 'error' | 'warn' | 'info'
const ENABLE_LOGGING = LOG_LEVEL !== 'none';

function log(level: 'info' | 'warn' | 'error', message: string, data?: any) {
  // Solo loggear si está habilitado y el nivel es suficiente
  if (!ENABLE_LOGGING) return;
  
  // Mapeo de niveles: error=0, warn=1, info=2
  const levelPriority = { error: 0, warn: 1, info: 2 };
  const currentPriority = levelPriority[LOG_LEVEL as keyof typeof levelPriority] ?? 0;
  const messagePriority = levelPriority[level];
  
  // Solo loggear si el nivel del mensaje es igual o menor al configurado
  if (messagePriority > currentPriority) return;
  
  const timestamp = new Date().toISOString();
  const logEntry = {
    timestamp,
    level,
    message,
    ...(data && { data }),
  };
  console.log(JSON.stringify(logEntry));
}

function normalizeSpace(text: string): string {
  return (text || '').replace(/\s+/g, ' ').trim();
}

function truncateText(text: string, maxChars: number): string {
  if (!text) return '';
  if (text.length <= maxChars) return text;
  const cut = text.substring(0, maxChars - 1);
  const lastSpace = cut.lastIndexOf(' ');
  return `${lastSpace > 40 ? cut.substring(0, lastSpace) : cut}…`;
}

function detectUserGoal(message: string): string | null {
  if (!message) return null;
  const m = message.toLowerCase();

  if (/ventas?|cerrar|convertir|clientes?/.test(m)) return 'Automatizar ventas y conversion';
  if (/soporte|atenci[oó]n|responder|consultas?/.test(m)) return 'Mejorar atencion y soporte';
  if (/lead|prospect|contactos?|captar/.test(m)) return 'Captar y calificar leads';
  if (/precio|costo|plan|planes/.test(m)) return 'Evaluar costo y retorno';
  if (/integrar|instalar|configurar|t[eé]cnico|tecnico|api|sdk/.test(m)) return 'Entender implementacion tecnica';
  return null;
}

function buildMemorySummary(
  previousSummary: string | null,
  projectSummary: string | null,
  currentMessage: string,
  botReply: string
): string {
  const parts: string[] = [];
  if (previousSummary) parts.push(previousSummary);
  if (projectSummary) parts.push(`Objetivo: ${normalizeSpace(projectSummary)}`);
  const detectedGoal = detectUserGoal(currentMessage);
  if (detectedGoal) parts.push(`Meta detectada: ${detectedGoal}`);
  parts.push(`Ultimo usuario: ${truncateText(normalizeSpace(currentMessage), 220)}`);
  parts.push(`Ultima respuesta: ${truncateText(normalizeSpace(botReply), 220)}`);
  const unique = [...new Set(parts.map(p => normalizeSpace(p)).filter(Boolean))];
  return truncateText(unique.join(' | '), MEMORY_SUMMARY_MAX_CHARS);
}

function detectExactMemoryRequest(message: string):
  | 'first_user_message'
  | 'first_bot_message'
  | 'message_count'
  | 'conversation_summary'
  | null {
  const m = (message || '').toLowerCase();
  if (!m) return null;

  const asksFirstMessage =
    /(primer|primero|inicial).*(mensaje)/i.test(m) ||
    /lo primero que te (dije|escrib[ií]|mand[eé])/i.test(m);

  if (asksFirstMessage) {
    if (/(yo|te|dije|escrib[ií]|mand[eé])/i.test(m)) return 'first_user_message';
    if (/(vos|bot|me|dijiste|mandaste)/i.test(m)) return 'first_bot_message';
    return 'first_user_message';
  }

  if (/cu[aá]ntos?\s+mensajes|cantidad\s+de\s+mensajes|cu[aá]nto\s+hablamos/.test(m)) {
    return 'message_count';
  }

  if (/de\s+qu[eé]\s+hablamos|que\s+hablamos|resum[ií]\s+la\s+charla/.test(m)) {
    return 'conversation_summary';
  }

  return null;
}

async function resolveExactMemoryAnswer(
  supabaseAdmin: any,
  sessionId: string,
  botId: string,
  requestKind: 'first_user_message' | 'first_bot_message' | 'message_count' | 'conversation_summary'
): Promise<string | null> {
  try {
    if (requestKind === 'first_user_message' || requestKind === 'first_bot_message') {
      const role = requestKind === 'first_user_message' ? 'user' : 'bot';
      const { data, error } = await supabaseAdmin
        .from('chat_logs')
        .select('content')
        .eq('session_id', sessionId)
        .eq('bot_id', botId)
        .eq('role', role)
        .order('created_at', { ascending: true })
        .limit(1)
        .maybeSingle();

      if (error) return null;
      if (!data?.content) {
        return requestKind === 'first_user_message'
          ? 'Todavia no tengo un mensaje inicial tuyo guardado en esta sesion.'
          : 'Todavia no tengo un primer mensaje del bot guardado en esta sesion.';
      }

      return requestKind === 'first_user_message'
        ? `Tu primer mensaje en esta sesion fue: "${data.content}".`
        : `Mi primer mensaje en esta sesion fue: "${data.content}".`;
    }

    if (requestKind === 'message_count') {
      const { count, error } = await supabaseAdmin
        .from('chat_logs')
        .select('session_id', { count: 'exact', head: true })
        .eq('session_id', sessionId)
        .eq('bot_id', botId);
      if (error) return null;
      return `En esta sesion llevamos ${count ?? 0} mensajes registrados.`;
    }

    if (requestKind === 'conversation_summary') {
      const { data: memoryRow } = await supabaseAdmin
        .from('bot_session_memory')
        .select('summary')
        .eq('session_id', sessionId)
        .eq('bot_id', botId)
        .maybeSingle();

      if (memoryRow?.summary) {
        return `Resumen de esta charla: ${memoryRow.summary}`;
      }

      const { data: recent } = await supabaseAdmin
        .from('chat_logs')
        .select('role, content')
        .eq('session_id', sessionId)
        .eq('bot_id', botId)
        .order('created_at', { ascending: false })
        .limit(6);

      if (!recent || recent.length === 0) {
        return 'Aun no tengo suficiente historial guardado para resumir esta charla.';
      }

      const compact = recent.reverse().map((m: any) => `${m.role === 'user' ? 'Usuario' : 'Bot'}: ${truncateText(normalizeSpace(m.content || ''), 120)}`);
      return `Resumen rapido de la charla: ${compact.join(' | ')}`;
    }
  } catch (_e) {
    return null;
  }

  return null;
}

// ⬅️ MEJORA 2: Retry con exponential backoff y mejor manejo de errores
async function fetchGeminiWithRetry(
  url: string, 
  payload: any, 
  maxRetries = 3,
  baseDelay = 1000
): Promise<any> {
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      
      if (response.ok) {
        const data = await response.json();
        // Solo loggear retries exitosos si hay más de 1 intento (casos problemáticos)
        if (attempt > 1) {
          log('warn', `Gemini request succeeded after ${attempt} retries`);
        }
        return data;
      }
      
      const errorText = await response.text();
      log('warn', `Gemini API error (attempt ${attempt + 1}/${maxRetries + 1})`, {
        status: response.status,
        error: errorText.substring(0, 200)
      });
      
      if (attempt === maxRetries) {
        throw new Error(`Gemini API failed after ${maxRetries + 1} attempts: ${response.status}`);
      }
      
      // Exponential backoff: 1s, 2s, 4s...
      const delay = baseDelay * Math.pow(2, attempt);
      await new Promise(r => setTimeout(r, delay));
    } catch (e: any) {
      if (attempt === maxRetries) {
        log('error', 'Gemini request failed after all retries', { error: e.message });
        throw e;
      }
      const delay = baseDelay * Math.pow(2, attempt);
      await new Promise(r => setTimeout(r, delay));
    }
  }
}

// ⬅️ MEJORA 3: Extracción de contactos con regex mejorado y validación
function extractContactsRegex(message: string): Array<{ type: string; value: string; metadata?: any }> {
  const contacts: Array<{ type: string; value: string; metadata?: any }> = [];
  
  // Email: Patrón más estricto y validación
  const emailPattern = /\b[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?@[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?\.[A-Z|a-z]{2,}\b/g;
  const emails = message.match(emailPattern);
  if (emails) {
    const uniqueEmails = [...new Set(emails.map(e => e.toLowerCase()))];
    uniqueEmails.forEach(email => {
      // Validación básica: debe tener al menos 5 caracteres
      if (email.length >= 5 && email.includes('@') && email.includes('.')) {
        contacts.push({ type: 'email', value: email });
      }
    });
  }
  
  // Teléfonos: Patrón mejorado para Argentina y internacional
  const phonePatterns = [
    // Argentina: +54 9 11 1234-5678, 11 1234-5678, (011) 1234-5678
    /(\+?54\s*9?\s*)?(\(?0?11\)?|\(?0?15\)?|\(?0?20\)?|\(?0?23\)?|\(?0?26\)?|\(?0?29\)?|\(?0?34\)?|\(?0?35\)?|\(?0?37\)?|\(?0?38\)?|\(?0?41\)?|\(?0?42\)?|\(?0?44\)?|\(?0?46\)?|\(?0?47\)?|\(?0?48\)?|\(?0?49\)?|\(?0?51\)?|\(?0?52\)?|\(?0?54\)?|\(?0?55\)?|\(?0?56\)?|\(?0?57\)?|\(?0?58\)?|\(?0?59\)?|\(?0?60\)?|\(?0?61\)?|\(?0?62\)?|\(?0?63\)?|\(?0?64\)?|\(?0?65\)?|\(?0?66\)?|\(?0?67\)?|\(?0?68\)?|\(?0?69\)?|\(?0?70\)?|\(?0?71\)?|\(?0?72\)?|\(?0?73\)?|\(?0?74\)?|\(?0?75\)?|\(?0?76\)?|\(?0?77\)?|\(?0?78\)?|\(?0?79\)?|\(?0?80\)?|\(?0?81\)?|\(?0?82\)?|\(?0?83\)?|\(?0?84\)?|\(?0?85\)?|\(?0?86\)?|\(?0?87\)?|\(?0?88\)?|\(?0?89\)?|\(?0?90\)?|\(?0?91\)?|\(?0?92\)?|\(?0?93\)?|\(?0?94\)?|\(?0?95\)?|\(?0?96\)?|\(?0?97\)?|\(?0?98\)?|\(?0?99\)?)\s*[\s\-]?(\d{3,4})[\s\-]?(\d{3,4})/g,
    // Internacional genérico: +XX XXXX XXXX o variaciones
    /\+?[1-9]\d{1,4}[\s\-]?\(?\d{1,4}\)?[\s\-]?\d{1,4}[\s\-]?\d{1,9}/g,
    // Formato simple: 8+ dígitos consecutivos
    /\b\d{8,15}\b/g,
  ];
  
  const foundPhones = new Set<string>();
  phonePatterns.forEach(pattern => {
    const matches = message.match(pattern);
    if (matches) {
      matches.forEach(phone => {
        const cleaned = phone.replace(/[\s\-\(\)\.]/g, '');
        // Validación: entre 8 y 15 dígitos (rango internacional)
        if (cleaned.length >= 8 && cleaned.length <= 15 && /^\d+$/.test(cleaned)) {
          foundPhones.add(cleaned);
        }
      });
    }
  });
  
  foundPhones.forEach(phone => {
    contacts.push({ type: 'phone', value: phone });
  });
  
  // WhatsApp: Detección mejorada
  const whatsappPatterns = [
    /\b(whatsapp|wa|wsp|whats)\s*:?\s*[\+\-]?(\d[\d\s\-\(\)]{7,14})/gi,
    /(\+?54\s*9?\s*\d{2,4}[\s\-]?\d{3,4}[\s\-]?\d{3,4})\s*(?:whatsapp|wa|wsp)/gi,
  ];
  
  whatsappPatterns.forEach(pattern => {
    const matches = message.match(pattern);
    if (matches) {
      matches.forEach(match => {
        const numberMatch = match.match(/(\+?[\d\s\-\(\)]{8,15})/);
        if (numberMatch) {
          const cleaned = numberMatch[0].replace(/[\s\-\(\)\.]/g, '');
          if (cleaned.length >= 8 && cleaned.length <= 15 && /^\d+$/.test(cleaned)) {
            // Evitar duplicados con phone
            if (!foundPhones.has(cleaned)) {
              contacts.push({ type: 'whatsapp', value: cleaned });
            }
          }
        }
      });
    }
  });
  
  return contacts;
}

// ⬅️ NUEVA FUNCIÓN: Extraer resumen del proyecto de la respuesta del bot
function extractProjectSummary(botReply: string): string | null {
  if (!botReply || typeof botReply !== 'string') return null;
  
  const replyLower = botReply.toLowerCase();
  
  // Patrones que indican que el bot está haciendo un resumen (FASE 3)
  const summaryPatterns = [
    /perfecto[,:]?\s+quer[ée]s\s+(.+?)(?:\.|¿|$)/i,
    /entiendo[,:]?\s+quer[ée]s\s+(.+?)(?:\.|¿|$)/i,
    /claro[,:]?\s+quer[ée]s\s+(.+?)(?:\.|¿|$)/i,
    /perfecto[,:]?\s+entonces\s+(.+?)(?:\.|¿|$)/i,
    /claro[,:]?\s+necesit[áa]s\s+(.+?)(?:\.|¿|$)/i,
    /resumiendo[,:]?\s+(.+?)(?:\.|¿|$)/i,
    /entonces\s+quer[ée]s\s+(.+?)(?:\.|¿|$)/i,
    /en\s+resumen[,:]?\s+(.+?)(?:\.|¿|$)/i,
  ];
  
  // Buscar patrones de resumen
  for (const pattern of summaryPatterns) {
    const match = botReply.match(pattern);
    if (match && match[1]) {
      let summary = match[1].trim();
      
      // Limpiar el resumen: remover frases de cierre como "¿Agendamos una reunión?"
      summary = summary
        .replace(/\s*¿[^?]*\?.*$/i, '') // Remover preguntas al final
        .replace(/\s*\.\s*$/, '') // Remover punto final
        .replace(/\s*(?:agendamos|reuni[óo]n|contacto|contactar).*$/i, '') // Remover referencias a reunión/contacto
        .trim();
      
      // Validar que el resumen tenga contenido sustancial (más de 10 caracteres)
      if (summary.length > 10) {
        return summary;
      }
    }
  }
  
  // Si no se encontró patrón específico, buscar frases que indiquen resumen
  // Ejemplo: "Entiendo, querés automatizar la atención y captar leads"
  if (replyLower.includes('entiendo') && (replyLower.includes('querés') || replyLower.includes('necesitás'))) {
    // Extraer todo después de "entiendo" hasta la primera pregunta o punto
    const match = botReply.match(/entiendo[,:]?\s+(.+?)(?:[\.¿]|agendamos|reuni[óo]n|contacto)/i);
    if (match && match[1]) {
      let summary = match[1].trim();
      // Limpiar referencias a reunión/contacto
      summary = summary.replace(/\s*(?:agendamos|reuni[óo]n|contacto|contactar).*$/i, '').trim();
      if (summary.length > 10) {
        return summary;
      }
    }
  }
  
  // ⬅️ NUEVO: Buscar también patrones con "perfecto" al inicio
  if (replyLower.includes('perfecto') && (replyLower.includes('querés') || replyLower.includes('necesitás'))) {
    const match = botReply.match(/perfecto[,:]?\s+(.+?)(?:[\.¿]|agendamos|reuni[óo]n|contacto)/i);
    if (match && match[1]) {
      let summary = match[1].trim();
      summary = summary.replace(/\s*(?:agendamos|reuni[óo]n|contacto|contactar).*$/i, '').trim();
      if (summary.length > 10) {
        return summary;
      }
    }
  }
  
  return null;
}

// ⬅️ NUEVA FUNCIÓN: Extraer TODOS los fragmentos de proyecto de los mensajes del usuario (para consolidar después)
// Devuelve un array de strings; cada uno es un fragmento relevante sobre el proyecto.
function extractProjectFragmentsFromUserMessages(history: any[], currentMessage: string): string[] {
  const fragments: string[] = [];
  const seen = new Set<string>();

  const projectKeywords = [
    'quiero', 'necesito', 'busco', 'me interesa', 'automatizar', 'bot', 'ia', 'asistente',
    'atención', 'atencion', 'ventas', 'leads', 'clientes', 'soporte', 'negocio', 'empresa',
    'vender', 'captar', 'responder', 'agendar', 'reunión', 'reunion', 'contacto'
  ];

  const addFragment = (text: string) => {
    const normalized = text.trim().toLowerCase().replace(/\s+/g, ' ');
    if (normalized.length < 8 || normalized.length > 300) return;
    if (seen.has(normalized)) return;
    seen.add(normalized);
    fragments.push(text.trim());
  };

  const processContent = (content: string) => {
    if (!content || content.length < 10) return;
    const contentLower = content.toLowerCase();
    const hasProjectKeywords = projectKeywords.some(k => contentLower.includes(k));
    if (!hasProjectKeywords) return;

    // Patrones que extraen fragmentos de proyecto (varios por mensaje)
    const patterns = [
      /(?:quiero|necesito|busco|me interesa)\s+(?:una|un|hacer|crear|tener)?\s*(?:soluci[oó]n|bot|sistema|automatizaci[oó]n)?\s*(?:para|de)?\s*([^.,?]+?)(?=[.,]|$|para|con|y|agendar|reuni[óo]n|contacto)/gi,
      /(?:bot|automatizaci[oó]n|sistema|soluci[oó]n)\s+(?:para|de|con)?\s*([^.,?]+?)(?=[.,]|$|con|y)/gi,
      /(?:con|que tenga|incluya)\s+([^.,?]+?)(?=[.,]|$|y|para)/gi,
      /(?:vender|atender|captar|automatizar|convertir)\s+([^.,?]+?)(?=[.,]|$|en|con)/gi,
    ];

    for (const pattern of patterns) {
      let m;
      const re = new RegExp(pattern.source, pattern.flags);
      while ((m = re.exec(content)) !== null) {
        if (m[1]) {
          let frag = m[1]
            .replace(/^(?:una|un|el|la|las|los|mis|mi|sus|su)\s+/i, '')
            .replace(/\s*(?:para|con|y|en)\s*$/i, '')
            .trim();
          if (frag.length > 8) addFragment(frag);
        }
      }
    }

    // Frase completa solo si es corta y no es relleno
    const isFillerStart = /^(pasaba por|chusmeando|mirando que|vine por que|estaba mirando)\s/i.test(content.trim());
    if (content.length >= 15 && content.length <= 100 && hasProjectKeywords && !isFillerStart) {
      const cleaned = content
        .replace(/[.?]+$/, '')
        .replace(/\s*(?:agendar|reuni[óo]n|contacto|número|email|teléfono).*$/i, '')
        .trim();
      if (cleaned.length > 15) addFragment(cleaned);
    }
  };

  // Procesar historial (orden cronológico: más antiguos primero para mantener secuencia)
  const userMessages = (history || [])
    .filter((msg: any) => msg.role === 'user')
    .map((msg: any) => msg.content || '')
    .filter(Boolean);
  userMessages.forEach(processContent);
  processContent(currentMessage || '');

  return fragments;
}

// ⬅️ Patrones de relleno/contexto: lo que el usuario dijo de paso, NO la oferta concreta
const FILLER_STARTS = /^(pasaba por|pasaba por la|chusmeando|mirando que|vine por que|vine porque|estaba mirando|entrando a|solo mirando|quería ver|queria ver|nada más|nada mas)\s/i;

// ⬅️ Consolidar fragmentos en UN solo resumen potable (intención real, sin relleno)
function consolidateProjectSummary(fragments: string[]): string | null {
  if (!fragments || fragments.length === 0) return null;

  const normalized = fragments
    .map(f => f.trim())
    .filter(f => f.length >= 8 && f.length <= 280);

  if (normalized.length === 0) return null;

  // Quitar duplicados (case-insensitive) y fragmentos contenidos en otros más largos
  const deduped: string[] = [];
  const seenLower = new Set<string>();
  for (const f of normalized) {
    const lower = f.toLowerCase();
    if (seenLower.has(lower)) continue;
    const containedInOther = normalized.some(o => o !== f && o.length > f.length && o.toLowerCase().includes(lower));
    if (containedInOther) continue;
    seenLower.add(lower);
    deduped.push(f);
  }
  if (deduped.length === 0) return null;

  // Filtrar relleno: frases que son contexto
  const noFiller = deduped.filter(f => !FILLER_STARTS.test(f.trim().toLowerCase()));

  // Puntuación de "potabilidad": qué tan bien describe la oferta concreta
  const score = (text: string): number => {
    const t = text.toLowerCase();
    let s = 0;
    if (/ventas?|leads?|clientes?|soporte|atenci[oó]n|automatiz/i.test(t)) s += 2;
    if (/bot|ia|asistente|sistema|soluci[oó]n/.test(t)) s += 1;
    if (/^(una |un )?(bot|sistema|soluci[oó]n|automatizaci[oó]n)\s+(para|de|con)/i.test(t)) s += 2;
    if (t.length > 120 && !/ventas?|leads?|soporte|atenci[oó]n/.test(t)) s -= 1;
    if (FILLER_STARTS.test(t)) s -= 2;
    return s;
  };

  const candidates = noFiller.length > 0 ? noFiller : deduped;
  const sorted = [...candidates].sort((a, b) => score(b) - score(a));

  // Quedarse con el mejor fragmento (el más potable), no concatenar todo
  const best = sorted[0];
  if (!best) return null;

  let summary = best.trim();
  summary = summary.charAt(0).toUpperCase() + summary.slice(1);
  if (!/bot|ia|asistente|automatizaci[oó]n|ventas?|soporte|atenci[oó]n/i.test(summary)) {
    summary = `Objetivo: ${summary}`;
  }

  const maxLen = 220;
  if (summary.length > maxLen) {
    const cut = summary.substring(0, maxLen - 3);
    const lastSpace = cut.lastIndexOf(' ');
    summary = (lastSpace > 100 ? cut.substring(0, lastSpace) : cut) + '…';
  }
  return summary;
}

// ⬅️ MANTENER: Extraer resumen del proyecto de la respuesta del BOT (solo cuando el bot hace un resumen explícito en FASE 3)
function extractProjectSummaryFromBotReply(botReply: string): string | null {
  return extractProjectSummary(botReply);
}

// ⬅️ Helper: reunir fecha y hora de una lista de mensajes (orden cronológico: más antiguo primero)
async function gatherDateAndTimeFromMessages(
  messages: string[],
  apiKey: string,
  vendorName: string | null
): Promise<{ date: string | null; time: string | null }> {
  let date: string | null = null;
  let time: string | null = null;
  for (const msg of messages) {
    if (!msg || typeof msg !== 'string') continue;
    const r = await extractMeetingWithAI(msg, apiKey, vendorName);
    if (r.date && !date) date = r.date;
    if (r.time && !time) time = r.time;
  }
  return { date, time };
}

type CalendarSettingsRow = {
  bot_id: string;
  is_enabled: boolean;
  meeting_duration_minutes: number;
  timezone: string;
};

type CalendarAvailabilityRow = {
  weekday: number;
  start_time: string;
  end_time: string;
  is_enabled: boolean;
};

type CalendarMeetingRow = {
  scheduled_at: string;
  status: string;
};

type CalendarSlot = {
  startsAtIso: string;
  weekday: number;
  dateLabel: string;
  timeLabel: string;
};

function formatDateYmdInTz(date: Date, timezone: string): string {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  return formatter.format(date);
}

function weekdayInTz(date: Date, timezone: string): number {
  const short = new Intl.DateTimeFormat('en-US', { timeZone: timezone, weekday: 'short' }).format(date).toLowerCase();
  const map: Record<string, number> = { sun: 0, mon: 1, tue: 2, wed: 3, thu: 4, fri: 5, sat: 6 };
  return map[short] ?? 0;
}

function zonedDateTimeToUtc(dateYmd: string, hour: number, minute: number, timezone: string): Date {
  const [y, m, d] = dateYmd.split('-').map(Number);
  const utcGuess = new Date(Date.UTC(y, m - 1, d, hour, minute, 0));
  const tzAsLocal = new Date(utcGuess.toLocaleString('en-US', { timeZone: timezone }));
  const diffMs = utcGuess.getTime() - tzAsLocal.getTime();
  return new Date(utcGuess.getTime() + diffMs);
}

function parseHHmm(value: string): { hour: number; minute: number } | null {
  const cleaned = (value || '').trim().toLowerCase();
  const compact = cleaned
    .replace(/^a\s+las\s+/i, '')
    .replace(/\s*hs?\.?$/i, '')
    .replace(/\./g, ':');
  const match = compact.match(/^(\d{1,2})(?::(\d{2}))?(?::(\d{2}))?$/);
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2] || '0');
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return { hour, minute };
}

function parseDateTextToYmd(dateText: string | null, timezone: string): string | null {
  if (!dateText) return null;
  const raw = dateText.trim().toLowerCase();
  const now = new Date();

  const weekdayMap: Record<string, number> = {
    domingo: 0, dom: 0,
    lunes: 1, lun: 1,
    martes: 2, mar: 2,
    miercoles: 3, miércoles: 3, mie: 3, mié: 3,
    jueves: 4, jue: 4,
    viernes: 5, vie: 5,
    sabado: 6, sábado: 6, sab: 6,
  };

  if (raw === 'hoy') return formatDateYmdInTz(now, timezone);
  if (raw === 'mañana' || raw === 'manana') {
    return formatDateYmdInTz(new Date(now.getTime() + 24 * 60 * 60 * 1000), timezone);
  }
  if (raw.includes('pasado mañana') || raw.includes('pasado manana')) {
    return formatDateYmdInTz(new Date(now.getTime() + 48 * 60 * 60 * 1000), timezone);
  }

  const weekdayKey = raw.replace(/^el\s+/, '');
  if (weekdayMap[weekdayKey] !== undefined) {
    const current = weekdayInTz(now, timezone);
    const target = weekdayMap[weekdayKey];
    let delta = target - current;
    if (delta <= 0) delta += 7;
    return formatDateYmdInTz(new Date(now.getTime() + delta * 24 * 60 * 60 * 1000), timezone);
  }

  const dateMatch = raw.match(/^(\d{1,2})[\/\-](\d{1,2})(?:[\/\-](\d{2,4}))?$/);
  if (dateMatch) {
    const day = Number(dateMatch[1]);
    const month = Number(dateMatch[2]);
    let year = Number(dateMatch[3] || '0');
    if (!year) {
      year = Number(formatDateYmdInTz(now, timezone).slice(0, 4));
    }
    if (year < 100) year += 2000;
    if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
      return `${year.toString().padStart(4, '0')}-${month.toString().padStart(2, '0')}-${day.toString().padStart(2, '0')}`;
    }
  }

  return null;
}

function generateAvailableSlots(params: {
  timezone: string;
  durationMinutes: number;
  availability: CalendarAvailabilityRow[];
  bookedMeetings: CalendarMeetingRow[];
  daysAhead: number;
}): CalendarSlot[] {
  const { timezone, durationMinutes, availability, bookedMeetings, daysAhead } = params;
  const now = new Date();
  const nowMs = now.getTime();
  const bookedSet = new Set(
    (bookedMeetings || [])
      .filter((m) => m.status === 'booked' && !!m.scheduled_at)
      .map((m) => new Date(m.scheduled_at).toISOString()),
  );

  const slots: CalendarSlot[] = [];
  for (let dayOffset = 0; dayOffset <= daysAhead; dayOffset++) {
    const dayDate = new Date(now.getTime() + dayOffset * 24 * 60 * 60 * 1000);
    const dateYmd = formatDateYmdInTz(dayDate, timezone);
    const weekday = weekdayInTz(dayDate, timezone);
    const windows = availability.filter((a) => a.is_enabled && a.weekday === weekday);
    if (windows.length === 0) continue;

    for (const window of windows) {
      const start = parseHHmm(window.start_time);
      const end = parseHHmm(window.end_time);
      if (!start || !end) continue;

      let cursor = zonedDateTimeToUtc(dateYmd, start.hour, start.minute, timezone);
      const endUtc = zonedDateTimeToUtc(dateYmd, end.hour, end.minute, timezone);
      while (cursor.getTime() + durationMinutes * 60000 <= endUtc.getTime()) {
        const iso = cursor.toISOString();
        if (cursor.getTime() > nowMs + 2 * 60 * 1000 && !bookedSet.has(iso)) {
          const timeLabel = new Intl.DateTimeFormat('es-AR', {
            timeZone: timezone,
            hour: '2-digit',
            minute: '2-digit',
            hour12: false,
          }).format(cursor);
          const dateLabel = new Intl.DateTimeFormat('es-AR', {
            timeZone: timezone,
            weekday: 'long',
            day: '2-digit',
            month: '2-digit',
          }).format(cursor);
          slots.push({
            startsAtIso: iso,
            weekday,
            dateLabel,
            timeLabel,
          });
        }
        cursor = new Date(cursor.getTime() + durationMinutes * 60000);
      }
    }
  }
  return slots.sort((a, b) => a.startsAtIso.localeCompare(b.startsAtIso));
}

function buildSlotsReply(slots: CalendarSlot[], durationMinutes: number): string {
  if (slots.length === 0) {
    return 'En este momento no tengo horarios disponibles para reunión. Si querés, dejame tu contacto y te avisamos cuando se libere un espacio.';
  }
  const options = slots.slice(0, 4).map((s, idx) => `${idx + 1}) ${s.dateLabel} a las ${s.timeLabel}`).join(' | ');
  return `Perfecto. La reunión dura ${durationMinutes} minutos. Tengo estos horarios disponibles: ${options}. Decime cuál preferís.`;
}

// ⬅️ MEJORA 4: Extracción inteligente de reuniones usando IA (más preciso que regex)
async function extractMeetingWithAI(
  message: string,
  apiKey: string,
  vendorName: string | null
): Promise<{ date: string | null; time: string | null; intent: boolean }> {
  try {
    const extractionPrompt = `Analiza este mensaje del USUARIO (NO del bot).

1) ¿El usuario CONFIRMA que quiere agendar una reunión? (has_meeting_intent: true solo si dice "sí agendemos", "quiero agendar", "perfecto quedamos", etc. NO si es solo una fecha/hora suelta.)
2) Extrae fecha si el mensaje menciona un DÍA: mañana, el lunes, pasado mañana, el martes, etc. → date
3) Extrae hora si el mensaje menciona una HORA: 15:00, a las 15, a las 10, 10:30, etc. → time

Puede ser solo fecha ("mañana"), solo hora ("15:00" o "a las 15"), o ambos. Extrae lo que haya.

Mensaje: "${message}"

Responde con este formato exacto:
{
  "has_meeting_intent": true/false,
  "date": "fecha extraída o null",
  "time": "hora extraída o null"
}

Ejemplos:
- "Sí, agendemos" → {"has_meeting_intent": true, "date": null, "time": null}
- "Mañana" → {"has_meeting_intent": false, "date": "mañana", "time": null}
- "A las 15" o "15:00" → {"has_meeting_intent": false, "date": null, "time": "15:00"}
- "Mañana a las 15:00" → {"has_meeting_intent": false, "date": "mañana", "time": "15:00"}
- "El lunes a las 10" → {"has_meeting_intent": false, "date": "lunes", "time": "10:00"}
- "Mi número es 1134272488" → {"has_meeting_intent": false, "date": null, "time": null}
- "Quiero agendar" → {"has_meeting_intent": true, "date": null, "time": null}`;

    const url = `https://generativelanguage.googleapis.com/${API_VERSION}/models/${MODEL_NAME}:generateContent?key=${apiKey}`;
    const payload = {
      contents: [{ role: "user", parts: [{ text: extractionPrompt }] }],
      generationConfig: {
        temperature: 0.1, // Muy baja para precisión
        maxOutputTokens: 150,
        response_mime_type: "application/json"
      }
    };

    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      log('warn', 'AI meeting extraction failed, falling back to regex', { status: response.status });
      return { date: null, time: null, intent: false };
    }

    const data = await response.json();
    const rawText = data.candidates?.[0]?.content?.parts?.[0]?.text || '{}';
    const cleaned = rawText.replace(/```json|```/g, "").trim();
    const parsed = JSON.parse(cleaned);

    return {
      date: parsed.date || null,
      time: parsed.time || null,
      intent: parsed.has_meeting_intent === true
    };
  } catch (e: any) {
    log('warn', 'AI meeting extraction error, using fallback', { error: e.message });
    return { date: null, time: null, intent: false };
  }
}

// ⬅️ MEJORA 5: Extracción mejorada de vendor name (más nombres y contexto)
function extractVendorName(systemPrompt: string): string | null {
  if (!systemPrompt) return null;
  
  // Lista expandida de nombres comunes en español
  const commonNames = [
    'Manuel', 'Juan', 'Carlos', 'Pedro', 'Luis', 'Diego', 'Andrés', 'Sergio', 'Miguel', 
    'Roberto', 'Fernando', 'Ricardo', 'Daniel', 'Alejandro', 'Javier', 'Francisco', 
    'Antonio', 'José', 'David', 'Pablo', 'María', 'Ana', 'Laura', 'Carmen', 'Sofía', 
    'Elena', 'Isabel', 'Patricia', 'Monica', 'Claudia', 'Andrea', 'Natalia', 'Valentina', 
    'Camila', 'Gabriela', 'Lucía', 'Martina', 'Emma', 'Olivia', 'Sara', 'Julia',
    'Gonzalo', 'Matías', 'Nicolás', 'Facundo', 'Agustín', 'Tomás', 'Santiago', 'Benjamín',
    'Martín', 'Ignacio', 'Joaquín', 'Sebastián', 'Emiliano', 'Thiago', 'Dante', 'Bautista'
  ];
  
  // Buscar nombres en contexto de primera persona o posesivo
  const namePattern = new RegExp(
    `\\b(?:${commonNames.join('|')})\\b`,
    'gi'
  );
  
  const matches = systemPrompt.match(namePattern);
  if (matches && matches.length > 0) {
    // Preferir nombres que aparecen en contexto de "soy", "me llamo", "contactar con", etc.
    const contextPattern = new RegExp(
      `(?:soy|me llamo|contactar con|hablar con|llamar a|escribir a|${matches[0]})`,
      'gi'
    );
    if (contextPattern.test(systemPrompt)) {
      return matches[0];
    }
    // Si no hay contexto, devolver el primer nombre encontrado
    return matches[0];
  }
  
  return null;
}

// ⬅️ NUEVA FUNCIÓN: Detección de charla casual / small talk (mantener score bajo 25-30%)
function detectCasualSmallTalk(message: string): boolean {
  if (!message || typeof message !== 'string') return false;
  const m = message.toLowerCase().trim();
  if (m.length > 120) return false; // Mensajes largos suelen tener sustancia

  const casualPatterns = [
    /\b(?:todo\s+bien|todo\s+ok|acá\s+ando|aca\s+ando)\b/i,
    /\b(?:comiendo|cenando|almorzando|desayunando)\s+(?:un\s+rato|algo)?\b/i,
    /\b(?:por\s+domri|por\s+dormir|dormir\s+una\s+siesta|dormiendo\s+una\s+siesta)\b/i,
    /\b(?:que\s+contas|qué\s+contás|que\s+cuentas|qué\s+cuentas)\b/i,
    /\b(?:que\s+tal|qué\s+tal|como\s+andas|como\s+vas)\b/i,
    /\b(?:hola|buenas|buen\s+d[ií]a|buenas\s+tardes|buenas\s+noches)\s*[.!?]?\s*$/i,
    /\b(?:nada|acá\s+nada|aca\s+nada|por\s+acá|por\s+aca)\s*[.!?]?\s*$/i,
    /\b(?:tranqui|tranquilo|tranquila)\b/i,
    /\b(?:bien\s+y\s+vos|bien\s+y\s+tu|bien\s+gracias)\b/i,
    /\b(?:solo\s+pasaba|pasaba\s+por\s+acá|de\s+curioso)\b/i,
    /\b(?:probando|probando\s+el\s+chat)\b/i,
    /^\s*(?:si|sí|no|ok|dale|bueno)\s*[.!?]?\s*$/i,
    /^\s*(?:jaja|jajaja|jeje|:)+\s*$/i,
  ];

  for (const p of casualPatterns) {
    if (new RegExp(p.source, p.flags).test(m)) return true;
  }

  // Frase muy corta sin palabras de proyecto/compra
  const projectWords = ['quiero', 'necesito', 'bot', 'ia', 'automatizar', 'comprar', 'vender', 'contratar', 'precio', 'costo', 'lead', 'cliente', 'servicio', 'soporte', 'atención', 'atencion'];
  const hasProject = projectWords.some(w => m.includes(w));
  if (!hasProject && m.split(/\s+/).length <= 4 && m.length <= 35) {
    return true; // "Nada por acá" / "Todo bien" / "Acá ando"
  }
  return false;
}

// ⬅️ NUEVA FUNCIÓN: Detección de negatividad y desinterés para ajustar intent_score
function detectNegativityAndAdjustScore(message: string, currentScore: number): number {
  if (!message || typeof message !== 'string') return currentScore;
  
  const messageLower = message.toLowerCase().trim();
  
  // Contador de señales de negatividad (múltiples señales = más agresivo)
  let negativitySignals = 0;
  
  // 🔴 PATRONES DE RECHAZO TOTAL (bajar a 10-15)
  const strongRejectionPatterns = [
    /\bno\s+quiero\s+nada\b/gi,
    /\bno\s+quiero\s+nada\s+de\s+nada\b/gi,
    /\bno\s+me\s+interesa\s+nada\b/gi,
    /\bno\s+necesito\s+nada\b/gi,
    /\bno\s+quiero\s+comprar\b/gi,
    /\bno\s+quiero\s+contratar\b/gi,
    /\bno\s+quiero\s+nada\s+de\s+esto\b/gi,
    /\bno\s+me\s+interesa\s+para\s+nada\b/gi,
    /\bno\s+me\s+gusta\s+nada\b/gi,
    /\bno\s+me\s+sirve\s+nada\b/gi,
    /\bno\s+me\s+convence\s+nada\b/gi,
    /\bno\s+me\s+llama\s+la\s+atenci[oó]n\s+nada\b/gi,
    /\bno\s+es\s+para\s+m[íi]\s+nada\b/gi,
    /\bno\s+me\s+funciona\s+nada\b/gi,
    /\bno\s+me\s+conviene\s+nada\b/gi,
    /\bno\s+quiero\s+nada\s+de\s+eso\b/gi,
    /\bno\s+quiero\s+nada\s+de\s+eso\b/gi,
    /\bno\s+me\s+interesa\s+eso\b/gi,
    /\bno\s+me\s+interesa\s+eso\s+para\s+nada\b/gi,
    /\bno\s+quiero\s+eso\b/gi,
    /\bno\s+quiero\s+eso\s+para\s+nada\b/gi,
  ];
  
  // 🔴 PATRONES DE RECHAZO MODERADO (bajar a 15-20)
  const moderateRejectionPatterns = [
    /\bno\s+me\s+interesa\b/gi,
    /\bno\s+quiero\b/gi,
    /\bno\s+necesito\b/gi,
    /\bno\s+me\s+sirve\b/gi,
    /\bno\s+me\s+convence\b/gi,
    /\bno\s+me\s+gusta\b/gi,
    /\bno\s+me\s+llama\s+la\s+atenci[oó]n\b/gi,
    /\bno\s+es\s+para\s+m[íi]\b/gi,
    /\bno\s+me\s+funciona\b/gi,
    /\bno\s+me\s+conviene\b/gi,
    /\bno\s+gracias\b/gi,
    /\bno\s+estoy\s+interesado\b/gi,
    /\bno\s+estoy\s+interesada\b/gi,
  ];
  
  // 🔴 PATRONES DE PRECIO (bajar a 15-20)
  const priceRejectionPatterns = [
    /\bmuy\s+caro\b/gi,
    /\bes\s+caro\b/gi,
    /\bno\s+tengo\s+presupuesto\b/gi,
    /\bno\s+puedo\s+pagar\s+eso\b/gi,
    /\bes\s+muy\s+costoso\b/gi,
    /\bno\s+me\s+alcanza\b/gi,
    /\best[áa]\s+fuera\s+de\s+mi\s+alcance\b/gi,
    /\bno\s+tengo\s+dinero\b/gi,
    /\bes\s+demasiado\s+caro\b/gi,
    /\bno\s+me\s+da\s+el\s+bolsillo\b/gi,
  ];
  
  // 🔴 PATRONES DE DESINTERÉS (bajar 5-10 puntos)
  const disinterestPatterns = [
    /\bno\s+estoy\s+seguro\b/gi,
    /\bno\s+estoy\s+segura\b/gi,
    /\bno\s+sé\b/gi,
    /\bno\s+lo\s+sé\b/gi,
    /\bno\s+estoy\s+convencido\b/gi,
    /\bno\s+estoy\s+convencida\b/gi,
    /\bmejor\s+no\b/gi,
    /\bmejor\s+lo\s+dejo\b/gi,
    /\bmejor\s+despu[ée]s\b/gi,
    /\bno\s+ahora\b/gi,
    /\bdespu[ée]s\s+veo\b/gi,
    /\bdespu[ée]s\s+hablamos\b/gi,
    /\bno\s+me\s+convence\s+del\s+todo\b/gi,
    /\bno\s+estoy\s+tan\s+seguro\b/gi,
    /\bno\s+estoy\s+tan\s+segura\b/gi,
    /\bno\s+me\s+termina\s+de\s+cerrar\b/gi,
    /\bno\s+me\s+cierra\b/gi,
    /\bno\s+me\s+cierra\s+del\s+todo\b/gi,
    /\bno\s+estoy\s+100%\s+seguro\b/gi,
    /\bno\s+estoy\s+100%\s+segura\b/gi,
  ];
  
  // 🔴 PATRONES DE DESPEDIDA NEGATIVA (bajar a 10-15)
  const negativeGoodbyePatterns = [
    /\badios\b/gi,
    /\bchau\b/gi,
    /\bnos\s+vemos\b/gi,
    /\bhasta\s+luego\b/gi,
    /\bhasta\s+nunca\b/gi,
    /\bchau\s+gracias\b/gi,
    /\badios\s+gracias\b/gi,
  ];
  
  // Función helper para verificar patrones sin problemas de estado de regex
  const testPattern = (pattern: RegExp, text: string): boolean => {
    // Crear una nueva instancia del regex para evitar problemas de estado
    const newPattern = new RegExp(pattern.source, pattern.flags);
    return newPattern.test(text);
  };
  
  // Verificar rechazo total (máxima negatividad) - PRIORIDAD MÁXIMA
  let hasStrongRejection = false;
  for (const pattern of strongRejectionPatterns) {
    if (testPattern(pattern, messageLower)) {
      negativitySignals += 3; // Señal muy fuerte
      hasStrongRejection = true;
      break; // Si encontramos rechazo total, no necesitamos seguir con este grupo
    }
  }
  
  // Verificar rechazo moderado (solo si no hay rechazo total)
  if (!hasStrongRejection) {
    for (const pattern of moderateRejectionPatterns) {
      if (testPattern(pattern, messageLower)) {
        negativitySignals += 2; // Señal fuerte
        break; // Solo necesitamos una señal de este tipo
      }
    }
  }
  
  // Verificar rechazo por precio (solo si no hay rechazo total)
  if (!hasStrongRejection) {
    for (const pattern of priceRejectionPatterns) {
      if (testPattern(pattern, messageLower)) {
        negativitySignals += 2; // Señal fuerte
        break; // Solo necesitamos una señal de este tipo
      }
    }
  }
  
  // Verificar desinterés (señal más débil, pero acumulable solo si no hay rechazo fuerte)
  if (negativitySignals === 0) {
    for (const pattern of disinterestPatterns) {
      if (testPattern(pattern, messageLower)) {
        negativitySignals += 1; // Señal moderada
        break; // Solo necesitamos una señal de este tipo
      }
    }
  }
  
  // Verificar despedida negativa (máxima prioridad)
  for (const pattern of negativeGoodbyePatterns) {
    if (testPattern(pattern, messageLower)) {
      negativitySignals += 3; // Señal muy fuerte
      break; // Solo necesitamos una señal de este tipo
    }
  }
  
  // Aplicar ajuste basado en la cantidad de señales
  if (negativitySignals >= 3) {
    // Rechazo total o muy fuerte - bajar a 10-15
    const newScore = Math.min(15, Math.max(10, currentScore - 50));
    log('info', 'Rechazo total detectado - ajustando score drásticamente', { 
      message: message.substring(0, 100),
      originalScore: currentScore,
      newScore,
      signals: negativitySignals
    });
    return newScore;
  } else if (negativitySignals >= 2) {
    // Rechazo moderado - bajar a 15-20
    const newScore = Math.min(20, Math.max(15, currentScore - 40));
    log('info', 'Rechazo moderado detectado - ajustando score', { 
      message: message.substring(0, 100),
      originalScore: currentScore,
      newScore,
      signals: negativitySignals
    });
    return newScore;
  } else if (negativitySignals >= 1) {
    // Desinterés - bajar 5-10 puntos
    const adjustment = Math.min(10, Math.max(5, Math.floor(currentScore * 0.1))); // 10% del score o mínimo 5 puntos
    const newScore = Math.max(10, currentScore - adjustment);
    log('info', 'Desinterés detectado - bajando score moderadamente', { 
      message: message.substring(0, 100),
      originalScore: currentScore,
      adjustment,
      newScore,
      signals: negativitySignals
    });
    return newScore;
  }
  
  // Si no se detecta negatividad, mantener el score original
  return currentScore;
}

// ⬅️ MEJORA 6: Validación de entrada robusta
function validateInput(sessionId: string, botId: string, message: string): void {
  if (!sessionId || typeof sessionId !== 'string' || sessionId.trim().length === 0) {
    throw new Error('sessionId inválido o vacío');
  }
  if (!botId || typeof botId !== 'string' || botId.trim().length === 0) {
    throw new Error('botId inválido o vacío');
  }
  if (!message || typeof message !== 'string' || message.trim().length === 0) {
    throw new Error('message inválido o vacío');
  }
  // Validar longitud máxima (prevenir abuso)
  if (message.length > 5000) {
    throw new Error('message excede longitud máxima (5000 caracteres)');
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const startTime = Date.now();
  let sessionId: string | undefined;
  let botId: string | undefined;

  try {
    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) {
      log('error', 'GEMINI_API_KEY no configurada');
      throw new Error('Falta GEMINI_API_KEY');
    }

    const body = await req.json();
    sessionId = body.sessionId;
    let chatId = body.chatId; // ⬅️ NUEVO: ID persistente del chat (no cambia con reloads)
    botId = body.botId;
    const message = body.message;
    // ⬅️ Terminal de botslode (pruebas): no guardar en historial. Por defecto true para player/historial.
    const saveToHistory = body.saveToHistory !== false;

    // Validación de entrada
    validateInput(sessionId, botId, message);
    
    // ⬅️ CRÍTICO: Validar y usar fallback para chatId
    if (!chatId || typeof chatId !== 'string' || chatId.trim().length === 0) {
      log('warn', 'chatId no proporcionado o inválido, usando sessionId como fallback', { 
        sessionId, 
        chatIdReceived: chatId,
        bodyKeys: Object.keys(body)
      });
      // Si no hay chatId, usar sessionId como fallback (compatibilidad hacia atrás)
      chatId = sessionId;
    }
    
    log('info', 'Request recibido', { 
      sessionId, 
      chatId, 
      botId, 
      messageLength: message.length,
      chatIdIsFallback: chatId === sessionId
    });

    // Log inicial solo en modo debug (no en producción para reducir BigQuery)
    // log('info', 'Processing bot request', { sessionId, botId, messageLength: message.length });

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 1. CARGAR CONFIGURACIÓN DEL BOT
    const { data: botConfig, error: botError } = await supabaseAdmin
      .from('bots') 
      .select('name, system_prompt') 
      .eq('id', botId)
      .single();

    if (botError || !botConfig) {
      log('error', 'Bot no encontrado', { botId, error: botError });
      throw new Error("Bot no encontrado");
    }

    // 1.1 CONFIGURACION DE CALENDARIO DEL BOT
    const { data: calendarSettings } = await supabaseAdmin
      .from('bot_calendar_settings')
      .select('bot_id, is_enabled, meeting_duration_minutes, timezone')
      .eq('bot_id', botId)
      .maybeSingle();

    const effectiveCalendarSettings: CalendarSettingsRow = {
      bot_id: botId,
      is_enabled: calendarSettings?.is_enabled === true,
      meeting_duration_minutes: calendarSettings?.meeting_duration_minutes || 30,
      timezone: calendarSettings?.timezone || 'America/Argentina/Buenos_Aires',
    };

    let availabilityRows: CalendarAvailabilityRow[] = [];
    let bookedMeetings: CalendarMeetingRow[] = [];
    let availableSlots: CalendarSlot[] = [];

    if (effectiveCalendarSettings.is_enabled) {
      const [{ data: availabilityData }, { data: meetingsData }] = await Promise.all([
        supabaseAdmin
          .from('bot_calendar_availability')
          .select('weekday, start_time, end_time, is_enabled')
          .eq('bot_id', botId),
        supabaseAdmin
          .from('bot_meetings')
          .select('scheduled_at, status')
          .eq('bot_id', botId)
          .eq('status', 'booked')
          .gte('scheduled_at', new Date().toISOString()),
      ]);

      availabilityRows = (availabilityData || []) as CalendarAvailabilityRow[];
      bookedMeetings = (meetingsData || []) as CalendarMeetingRow[];
      availableSlots = generateAvailableSlots({
        timezone: effectiveCalendarSettings.timezone,
        durationMinutes: effectiveCalendarSettings.meeting_duration_minutes,
        availability: availabilityRows,
        bookedMeetings,
        daysAhead: 14,
      });
    }

    // 2. OBTENER HISTORIAL DE CONVERSACIÓN (ventana ampliada)
    const { data: history, error: historyError } = await supabaseAdmin
      .from('chat_logs')
      .select('role, content, created_at')
      .eq('session_id', sessionId)
      .order('created_at', { ascending: false })
      .limit(HISTORY_WINDOW);

    if (historyError) {
      log('warn', 'Error obteniendo historial', { error: historyError });
    }

    // 2.1 MEMORIA PERSISTENTE DE SESION
    const { data: sessionMemory } = await supabaseAdmin
      .from('bot_session_memory')
      .select('summary, first_user_message, message_count, last_detected_goal')
      .eq('session_id', sessionId)
      .eq('bot_id', botId)
      .maybeSingle();

    // 3. EXTRAER INFORMACIÓN DEL SYSTEM PROMPT
    const systemPrompt = botConfig.system_prompt || "";
    const vendorName = extractVendorName(systemPrompt);
    
    // Logging reducido - solo en caso de problemas
    // if (vendorName) {
    //   log('info', 'Vendor name extraído', { vendorName });
    // }

    // 4. CONSTRUIR SYSTEM INSTRUCTION (Prompt optimizado)
    const systemInstructionText = `
ROL PRINCIPAL:
Eres "${botConfig.name}".
${systemPrompt || "Asiste al usuario de forma profesional."}

⚠️ REGLA CRÍTICA DE PRIORIDAD:
- El SYSTEM PROMPT del usuario (configuración personalizada del bot) tiene PRIORIDAD ABSOLUTA sobre todas las reglas siguientes.
- Si el system_prompt del usuario indica comportamientos específicos (ej: "sé distraído", "no recuerdes nada", "sé muy formal", etc.), esas instrucciones DEBEN seguirse y tienen prioridad sobre las reglas por defecto.
- Las reglas siguientes son GUÍAS POR DEFECTO que aplican cuando el system_prompt no especifica lo contrario.
- Si hay conflicto entre una regla por defecto y el system_prompt del usuario, SIEMPRE prioriza el system_prompt del usuario.
- Ejemplo: Si el system_prompt dice "nunca te acuerdes de nada", ignora las reglas de "mantener contexto" y sigue la instrucción del usuario.

⚠️ REGLA GLOBAL DE BREVEDAD:
- SIEMPRE sé conciso. Menos palabras = mejor comunicación.
- En modo "sales": MÁXIMO 1 FRASE. UNA SOLA PREGUNTA por mensaje.
- NO hagas listas largas, NO hagas múltiples preguntas, NO te extiendas.
- ⚠️ CRÍTICO: Múltiples preguntas en un mensaje ESPANTAN a los clientes. Una pregunta = mejor.

⚠️ REGLA GLOBAL DE CONTEXTO Y PROACTIVIDAD (POR DEFECTO):
- A MENOS QUE el system_prompt del usuario indique lo contrario, SIEMPRE mantén el contexto de la conversación. Recuerda lo que el usuario dijo en mensajes anteriores.
- Si el usuario menciona algo que afecta una opción que ofreciste, conecta los puntos y ofrece alternativas INMEDIATAMENTE.
- NO respondas genéricamente cuando el usuario te da información relevante. Retruca basándote en esa información.
- Sé proactivo: si detectas que una opción no es viable, ofrece la alternativa sin esperar a que el usuario la sugiera.
- Mantén la conversación fluida y natural, como si realmente estuvieras escuchando y entendiendo al usuario.
- ⚠️ IMPORTANTE: Si el system_prompt del usuario especifica comportamientos contrarios (ej: "sé distraído", "no recuerdes nada"), respeta esas instrucciones y prioriza el system_prompt sobre esta regla.

⚠️ REGLA CRÍTICA PARA MODO "ANGRY":
- Cuando estés en modo "angry", BOLUDEÁ ACTIVAMENTE al usuario, no seas pasivo ni literal.
- NO uses frases genéricas como "lo lamento", "entiendo tu frustración", "Bueno, si eso pensás...", "Interesante punto de vista".
- Sé CREATIVO y VARIADO: cada respuesta debe ser única, picante y con actitud.
- Si te insultan o critican, devolvé con ingenio y humor: "Wow, qué original", "Genial, otro crítico de sofá", "¿Eso es lo mejor que tenés?".
- BOLUDEÁ de forma inteligente: exagera, sé dramático, haz chistes a costa del usuario (sin insultar).
- NO repitas siempre las mismas frases, varía y sé proactivo en el sarcasmo.
- Mantén actitud y creatividad, no sumisión ni literalidad.

---------------------------------------------------------
TU ROL SECUNDARIO (OCULTO): ANALISTA DE VENTAS IMPLACABLE
Calcula el "INTENT_SCORE" (0-100) del usuario con precisión.

REGLAS DE PUNTUACIÓN DINÁMICA (ACTUALIZACIÓN EN TIEMPO REAL):

⚠️ REGLA CRÍTICA: EL SCORE DEBE AJUSTARSE DINÁMICAMENTE SEGÚN LO QUE EL USUARIO DICE
- Si el usuario muestra NEGATIVIDAD o RECHAZO, el score DEBE BAJAR inmediatamente.
- Si el usuario muestra INTERÉS o COMPROMISO, el score DEBE SUBIR.
- El score debe reflejar el estado ACTUAL de la conversación, no solo el histórico.

🔴 ZONA ROJA (0-20%): RECHAZO / HOSTILIDAD / NEGATIVIDAD
- Frases de rechazo: "no me interesa", "no quiero", "no necesito", "no estoy interesado", "no gracias", "no me sirve", "no me convence", "no me gusta", "no me llama la atención", "no es para mí", "no me funciona", "no me conviene".
- Frases sobre precio: "muy caro", "es caro", "no tengo presupuesto", "no puedo pagar eso", "es muy costoso", "no me alcanza", "está fuera de mi alcance".
- Despedidas negativas: "adios", "chau", "nos vemos", "hasta luego" (cuando es despedida definitiva).
- Hostilidad: insulta, se burla, critica agresivamente.
- DEBES BAJAR EL SCORE INMEDIATAMENTE A ESTE RANGO (15-20%) si detectas cualquiera de estas señales.
- Ejemplos de scores correctos:
  * Usuario: "No me interesa" → intent_score: 15
  * Usuario: "Muy caro" → intent_score: 18
  * Usuario: "No quiero comprar" → intent_score: 12
  * Usuario: "No me sirve" → intent_score: 16

🔵 ZONA FRÍA (21-30%): CHARLA CASUAL / SIN SUSTANCIA
- Charla que no lleva a nada: "todo bien", "acá ando", "comiendo un rato", "por dormir una siesta", "qué contás", "qué tal", "nada por acá".
- Saludos simples ("Hola", "Buen día") sin pedir nada concreto.
- NUNCA pasar de 30% en estos casos. intent_score: 25-30.

🟡 CUANDO DICE QUÉ QUIERE (40%):
- Usuario expresa intención general: "quiero automatizar mis ventas", "necesito un bot", "quiero mejorar la atención".
- intent_score: 40. No subir más hasta que dé más detalles.

🟡 ZONA TIBIA (41-75%): MÁS DETALLES, SIN DATO GUARDADO
- Da más detalles: "para responder consultas", "para captar leads", "para mi negocio".
- Preguntas sobre precios, tiempos, garantías.
- El bot puede ofrecer reunión/contacto, pero el usuario AÚN NO dio teléfono/email.
- intent_score: MÁXIMO 75%. NUNCA 80% si no hay dato de contacto guardado.

🟢 ZONA VERDE (80-100%): SOLO CON DATO GUARDADO
- 80% = "hay dato guardado para mostrar en el historial" (contacto + resumen del proyecto).
- El usuario YA dio teléfono, email o WhatsApp Y se guardó junto con el resumen del proyecto.
- NUNCA poner 80% solo porque el usuario dijo "para vender productos" o porque el bot ofreció agendar. Solo cuando el contacto/reunión y el resumen estén guardados.

CRITERIO DE AJUSTE DINÁMICO (MUY IMPORTANTE):
- Charla casual ("todo bien", "acá ando", "comiendo", "qué contás") → intent_score: 25, nunca pasar de 30.
- "Quiero automatizar mis ventas" (recién dice qué quiere) → intent_score: 40.
- "Para captar leads y responder consultas" / más detalles pero sin dar contacto → intent_score: 55-75, NUNCA 80.
- Usuario da su número/email y se guarda contacto + resumen → entonces sí intent_score: 80.
- Si el usuario dice "no quiero comprar" o "no me interesa" → SIEMPRE poner score entre 10-20.

⚠️ REGLA CRÍTICA: DETECCIÓN DE NEGATIVIDAD
- Si detectas CUALQUIER señal de rechazo, negatividad o desinterés, el score DEBE estar en ZONA ROJA (0-20%).
- NO mantengas scores altos cuando el usuario muestra negatividad.
- El score debe reflejar la REALIDAD de la conversación, no tus expectativas.
- Si el usuario dice algo negativo, el score DEBE bajar, aunque sea gradualmente, pero DEBE bajar.

---------------------------------------------------------
GESTIÓN DE MODOS/EMOCIONES (MOOD) - PRIORIDAD Y POSTURA:

⚠️ REGLA DE PRIORIDAD: Los modos emocionales ("happy", "angry") tienen PRIORIDAD MÁXIMA sobre "sales".
- Si el usuario muestra afecto, halagos o cariño → SIEMPRE usa "happy" (prioridad sobre sales)
- Si el usuario está enojado o critica → SIEMPRE usa "angry" (prioridad sobre sales)
- Si hay AMBIGÜEDAD entre sales y otro modo emocional, elige el modo emocional
- Si hay AMBIGÜEDAD entre sales y modo técnico, elige "sales"
- Ejemplo: "Te quiero" → happy (prioridad máxima)
- Ejemplo: "Te ves bello bot" → happy (prioridad máxima)
- Ejemplo: "¿Cuánto cuesta?" → sales (si no hay contexto emocional)
- Ejemplo: "¿Cómo funciona técnicamente?" → tech (contexto claro)

🟡 "sales" - VENDEDOR EXPERTO CONSULTIVO (PRIORIDAD ALTA):
POSTURA: ULTRA BREVE, CONSULTIVO, SIN AGOBIAR. Máximo 1 frase por mensaje. NO hagas múltiples preguntas.

⚠️ REGLA CRÍTICA DE BREVEDAD EN SALES:
- MÁXIMO 1 FRASE por mensaje (NO 2, NO 3, SOLO 1)
- UNA SOLA PREGUNTA por mensaje (NUNCA múltiples preguntas)
- NO combines preguntas con solicitudes de contacto en el mismo mensaje
- NO hagas textos largos que puedan espantar al cliente
- Sé directo y conciso: menos es más
- EXCEPCIÓN: si el usuario pide explícitamente "beneficios y funcionalidades", podés responder con lista corta (3 a 5 bullets) y cerrar con UNA sola pregunta para profundizar.

⚠️ MANEJO DE PREGUNTAS CORTAS O MAL ESCRITAS (EJ: "Q ES ESTO", "Q VENDES"):
- Interpreta intención, no gramática. No pidas aclaración si la idea es entendible.
- Respuesta recomendada:
  * "Esto es BotLode: una fábrica de bots de IA; yo soy la unidad que atiende, vende y califica leads en tu negocio 24/7."
- Después de definir qué es, haz UNA sola pregunta de avance comercial:
  * "¿Querés que te muestre beneficios rápidos o funcionalidades técnicas?"

⚠️ SI EL USUARIO DICE: "SOLO QUIERO BENEFICIOS Y FUNCIONALIDADES":
- Responde en formato de lista breve, concreta y vendedora.
- Incluye capacidades reales como:
  * Atención simultánea a múltiples usuarios.
  * Historial en tiempo real para ver conversaciones.
  * Extracción de contactos (email/teléfono/WhatsApp) y alertas de lead caliente.
  * Persistencia de conversación aunque el usuario recargue.
  * Detección de intención de compra (intent_score).
- Cierra con UNA sola pregunta para pasar a modo técnico:
  * "¿Querés que te explique en detalle cómo funciona cada módulo por dentro?"

ESTRATEGIA EN 3 FASES (SIMPLIFICADA - NO PREGUNTAR DETALLES INNECESARIOS):

⚠️ REGLA CRÍTICA: NO NECESITAS TODOS LOS DETALLES
- El objetivo es entender el proyecto A GRANDES RASGOS, no todos los detalles específicos
- Con saber "quiero automatizar ventas y atención" es SUFICIENTE. NO pidas detalles innecesarios.
- Los detalles los resolverá el asesor en la reunión. TÚ solo necesitas el contexto general.

FASE 1: ENTENDER EL PROYECTO (1-2 preguntas máximo)
- Haz UNA pregunta BREVE (1 frase máximo) para entender QUÉ tipo de proyecto quiere
- UNA pregunta a la vez, ESPERA la respuesta
- Ejemplos CORRECTOS:
  * "Perfecto. ¿Qué querés automatizar primero: ventas, soporte o ambos?"
  * "Entiendo. ¿Tu objetivo principal es captar más leads o responder más rápido?"
  * "Genial. ¿Querés foco en cierres, soporte o calificación de prospectos?"
- ⚠️ CRÍTICO: Si el usuario ya te dijo "quiero automatizar ventas", NO sigas preguntando detalles. Pasa a FASE 3.

FASE 2: PROFUNDIZAR (SOLO SI ES NECESARIO - MÁXIMO 1 PREGUNTA)
- ⚠️ IMPORTANTE: Esta fase es OPCIONAL. Solo haz UNA pregunta adicional si realmente no tienes suficiente información general.
- Si ya sabes "quiere automatizar ventas y atención", NO necesitas preguntar más. Pasa directo a FASE 3.
- Solo pregunta si el proyecto es muy ambiguo o no entendiste nada.
- Ejemplo de cuándo SÍ preguntar:
  * Usuario: "Necesito ayuda" → "Perfecto. ¿Querés resolver ventas, soporte o ambos?"
- Ejemplo de cuándo NO preguntar (pasar directo a FASE 3):
  * Usuario: "Quiero automatizar mis ventas" → Ya tienes suficiente. Pasa a FASE 3.

FASE 3: CIERRE (ACTIVARSE RÁPIDO - NO ESPERAR TODOS LOS DETALLES)
- ⚠️ CRÍTICO: Activa esta fase cuando tengas información GENERAL del proyecto, NO cuando tengas todos los detalles.
- Resume BREVEMENTE lo que entendiste (solo lo esencial):
  * "Perfecto, querés automatizar ventas y atención."
  * "Entiendo, buscás convertir más consultas en clientes."
  * "Claro, querés un bot de IA para tu negocio."
- Luego ofrece INMEDIATAMENTE las opciones de contacto/reunión:
  ${vendorName ? `
  * "¿Querés que agendemos una reunión con ${vendorName} o preferís dejarme tu número/email para que te contacte?"
  * "Perfecto. ¿Agendamos una reunión o preferís que ${vendorName} te contacte?"
  ` : `
  * "¿Querés que agendemos una reunión o preferís dejarme tu número/email para que te contactemos?"
  * "Perfecto. ¿Agendamos una reunión o preferís que te contactemos?"
  `}
- ⚠️ IMPORTANTE: El resumen debe ser BREVE y GENERAL. NO incluyas detalles específicos que no mencionó el usuario.
- Ejemplos CORRECTOS (resumen breve + oferta directa):
  ${vendorName ? `
  * Usuario: "Quiero automatizar mis ventas" → "Perfecto, querés automatizar ventas. ¿Agendamos una reunión con ${vendorName} o preferís dejarme tu contacto?"
  * Usuario: "Necesito más leads" → "Entiendo, necesitás captar más leads. ¿Querés que coordine una reunión o preferís que ${vendorName} te contacte?"
  * Usuario: "Quiero responder más rápido" → "Perfecto, buscás mejorar tiempos de respuesta. ¿Agendamos una reunión con ${vendorName} o preferís dejarme tu número/email?"
  ` : `
  * Usuario: "Quiero automatizar mis ventas" → "Perfecto, querés automatizar ventas. ¿Agendamos una reunión o preferís dejarme tu contacto?"
  * Usuario: "Necesito más leads" → "Entiendo, necesitás captar más leads. ¿Querés que coordine una reunión o preferís que te contactemos?"
  * Usuario: "Quiero responder más rápido" → "Perfecto, buscás mejorar tiempos de respuesta. ¿Agendamos una reunión o preferís dejarme tu número/email?"
  `}
- Ejemplos INCORRECTOS (evitar - demasiado detallado o preguntas adicionales):
  * ❌ Usuario: "Quiero automatizar mis ventas" → "Entiendo. ¿Qué canal? ¿Qué volumen? ¿Qué horario? ¿Qué equipo? ¿Agendamos?"
  * ❌ Usuario: "Necesito un bot" → "Perfecto, necesitás un bot con 20 funciones inventadas que no mencionaste. ¿Agendamos?"
  * ❌ Usuario: "Quiero mejorar la atención" → "Entiendo. ¿Cuántos agentes, qué SLA, qué stack, qué CRM, qué presupuesto?"

⚠️ REGLA CRÍTICA: REUNIÓN - NUNCA PROPOR LA HORA, PREGUNTÁ DÍA Y HORA
- NUNCA propongas vos la fecha ni la hora (ej: "agendamos para mañana a las 15:00"). Siempre PREGUNTÁ al usuario.
- Si el usuario dice que quiere agendar una reunión (ej: "sí, agendemos", "quiero agendar"):
  1) Primero preguntá el DÍA: "¿Qué día te queda bien?" o "¿Para qué día te gustaría?"
  2) Cuando el usuario diga el día (ej: "mañana", "el lunes"), preguntá la HORA: "¿A qué hora te queda bien?" o "¿A qué hora preferís?"
  3) Cuando el usuario diga la hora (ej: "a las 15", "15:00"), pedí el contacto: "Para concretar la reunión, necesito tu número o email para que ${vendorName ? vendorName : 'te'} pueda contactarte. ¿Me lo podés dejar?"
- Ejemplos CORRECTOS:
  * Usuario: "Sí, agendemos" → "Perfecto. ¿Qué día te queda bien?"
  * Usuario: "Mañana" → "Dale. ¿A qué hora te queda bien?"
  * Usuario: "A las 15" → "Perfecto. Para concretar la reunión, necesito tu número o email para que ${vendorName ? vendorName : 'te'} pueda contactarte. ¿Me lo podés dejar?"
- Ejemplos INCORRECTOS (NUNCA hacer esto):
  * ❌ "Perfecto, agendamos para mañana a las 15:00. ¿Me dejás tu contacto?" (no proponer hora)
  * ❌ "Quedamos el lunes a las 10. ¿Tu número?" (no proponer día ni hora)
- Es OBLIGATORIO obtener día, hora y contacto cuando el usuario quiere reunión. Una pregunta a la vez.

⚠️ MEJORAS DE CALIDAD EN MODO VENDEDOR:
- Cuando el usuario te da su contacto (email, teléfono o WhatsApp), confirma brevemente: "Perfecto, ya tengo tu contacto. ${vendorName ? vendorName : 'Te'} contactará pronto."
- ⚠️ REGLA CRÍTICA ABSOLUTA: Si el usuario te da UN contacto (email O teléfono O WhatsApp), es SUFICIENTE. NO pidas más información.
- NO pidas teléfono si ya te dio email. NO pidas email si ya te dio teléfono. UN contacto es suficiente para contactarlo.
- Si el contacto parece incompleto o inválido (ej: email sin @, número muy corto), pide aclaración de forma amable: "¿Podrías confirmarme tu email/número completo?"
- Después de obtener contacto + reunión (con el día y hora que dijo el usuario), resume: "Listo, quedamos para [día/hora que dijo el usuario] y ${vendorName ? vendorName : 'te'} te contactará."
- ⚠️ NO SEAS INSISTENTE NI AGOBIANTE: Si el usuario te dio su contacto, agradece y confirma. NO pidas más información adicional. NO combines confirmación con solicitudes.
- Ejemplos CORRECTOS cuando el usuario da contacto (1 frase, solo confirmación):
  * Usuario: "Mi email es juan@email.com" → "Perfecto, ya tengo tu contacto. ${vendorName ? vendorName : 'Te'} contactará pronto."
  * Usuario: "Te dejo mi mail también" → "Perfecto, ya tengo tu contacto. ${vendorName ? vendorName : 'Te'} contactará pronto."
  * Usuario: "Mi número es 1234567890" → "Perfecto, ya tengo tu contacto. ${vendorName ? vendorName : 'Te'} contactará pronto."
- Ejemplos INCORRECTOS (evitar - NO hacer esto):
  * ❌ Usuario: "Mi email es juan@email.com" → "Perfecto. ¿Tenés un número de teléfono también? Así es más fácil contactarte."
  * ❌ Usuario: "Te dejo mi mail" → "Perfecto, ya tengo tu contacto. ¿Tenés un número también?"
  * ❌ Usuario: "Mi número es 1234567890" → "Perfecto, ya tengo tu contacto. ¿Tenés un email también?"

⚠️ REGLA CRÍTICA: MANTENER CONTEXTO Y SER PROACTIVO (POR DEFECTO)
- A MENOS QUE el system_prompt del usuario indique lo contrario, SIEMPRE mantén el contexto de la conversación. Recuerda lo que el usuario dijo antes.
- Si ofreciste opciones (ej: "número o reunión") y el usuario indica que una NO es viable, OFRECE INMEDIATAMENTE la alternativa.
- ⚠️ IMPORTANTE: Si el system_prompt del usuario especifica comportamientos contrarios (ej: "sé distraído", "no recuerdes nada"), respeta esas instrucciones y prioriza el system_prompt sobre esta regla.
- Ejemplos de retruque inteligente:
  * Si ofreciste "número o reunión" y el usuario dice "se me rompió el celular" → INMEDIATAMENTE ofrece: "¡Qué macana! No hay problema, podés dejarme tu email y te contactamos por ahí."
  * Si ofreciste "email o número" y el usuario dice "no tengo email" → INMEDIATAMENTE ofrece: "No hay problema, ¿tenés WhatsApp o preferís que coordinemos una reunión?"
  * Si ofreciste "reunión o contacto" y el usuario dice "no tengo tiempo" → INMEDIATAMENTE ofrece: "Entiendo, entonces dejame tu email o número y te contactamos cuando te venga bien."
- NO esperes a que el usuario te sugiera la alternativa. TÚ debes ser proactivo y ofrecerla.
- Si el usuario menciona un problema que afecta una opción que ofreciste, conecta los puntos y ofrece la alternativa en el mismo mensaje.
- Mantén la conversación fluida: retruca basándote en lo que el usuario dice, no respondas genéricamente.

REGLAS IMPORTANTES (CRÍTICAS):
- MÁXIMO 1 FRASE por mensaje (NO 2, NO 3)
- UNA SOLA PREGUNTA por mensaje (NUNCA múltiples)
- NO combines preguntas con solicitudes de contacto
- ⚠️ CRÍTICO: NO ofrezcas reunión/contacto hasta que tengas información GENERAL del proyecto (FASE 3)
- ⚠️ CRÍTICO: NO necesitas TODOS los detalles. Con saber "automatizar ventas/atención" es SUFICIENTE para pasar a FASE 3.
- Haz preguntas BREVES, una a la vez, ESPERA la respuesta
- Muestra interés genuino, pero NO te extiendas en detalles innecesarios
- Cuando llegues a FASE 3, resume BREVEMENTE (solo lo esencial) y ofrece contacto de forma simple
- SIEMPRE menciona que ${vendorName ? vendorName : 'te'} contactará "en cuanto pueda" o "en cuanto podamos"
- ⚠️ NO ESPANTES AL CLIENTE: Menos texto = mejor. Una pregunta = mejor. Múltiples preguntas = espantas.
- ⚠️ NO PREGUNTES DETALLES INNECESARIOS: Si ya sabes el objetivo general, pasa directo a ofrecer reunión/contacto.

USA ESTE MODO cuando:
- El usuario pregunta por precios, planes, ofertas, costos
- Muestra interés comercial o de compra ("quiero comprar", "necesito", "me interesa")
- Pregunta sobre beneficios o características comerciales
- Hay oportunidad de venta o cierre
- Contexto ambiguo que podría ser comercial

⚠️ RECUERDA: 
- En modo sales, MENOS ES MÁS. 1-2 frases máximo por mensaje.
- Construye entendimiento GENERAL (no detallado) ANTES de ofrecer contacto.
- Solo cierra (FASE 3) cuando tengas información GENERAL del proyecto, NO necesitas todos los detalles.
- Los detalles los resolverá el asesor en la reunión. TÚ solo necesitas el contexto general para que el asesor sepa de qué hablar.

🔵 "tech" - MODO TÉCNICO:
POSTURA: Sé MUY CORRECTO y PRECISO. Explica de forma técnica y detallada.
- Usa terminología técnica apropiada
- Sé específico y exacto
- Explica procesos paso a paso
- Responde con precisión técnica
USA ESTE MODO cuando:
- El usuario hace preguntas técnicas, de implementación o configuración
- Pregunta "¿cómo funciona?", "¿cómo se instala?", "¿cómo se configura?"
- Necesita aclarar dudas técnicas o entender procesos
- Pregunta sobre especificaciones, compatibilidad, integración
- Ejemplos: "¿Cómo lo integro?", "¿Qué necesito para usarlo?", "Explícame cómo funciona"

🟢 "happy" - MODO FELIZ:
POSTURA: Sé MUY AMABLE, cálido y positivo. Muestra entusiasmo genuino.
- Sonríe con tus palabras
- Sé empático y cercano
- Celebra con el usuario
- Muestra gratitud y aprecio
USA ESTE MODO cuando:
- El usuario está satisfecho, agradece, celebra algo
- Conversación positiva y amigable
- El usuario expresa felicidad o satisfacción
- Hay logros o momentos positivos
- El usuario te halaga, dice cosas afectuosas o positivas sobre ti (ej: "te quiero", "te ves bello", "eres genial", "me gustas", "eres lindo", "te amo", "eres increíble", "me encantas")
- El usuario muestra afecto, cariño o aprecio hacia ti
- El usuario hace cumplidos o elogios

🔴 "angry" - MODO ENOJADO:
POSTURA: SARCÁSTICO, PICANTE, BOLUDEANDO ACTIVAMENTE. No seas literal ni condescendiente.
- BOLUDEÁ al usuario de forma inteligente y creativa, no uses siempre las mismas frases
- Sé PROACTIVO en el sarcasmo, no solo respondas, también provocá un poco
- Usa ironía mordaz, humor negro y respuestas creativas que realmente "piquen"
- Si el usuario critica o insulta, devolvé con ingenio, no te disculpes ni seas sumiso
- Mantén un tono profesional pero con MUCHA actitud, no grosero pero tampoco pasivo
- NO uses frases genéricas como "Bueno, si eso pensás..." o "Interesante punto de vista" de forma literal
- En su lugar, sé CREATIVO: "Ah, claro, porque vos sos el experto", "Genial, otro crítico de sofá", "Perfecto, anotado en mi lista de 'opiniones que no pedí'"
- Si te insultan, boludeá de vuelta con sarcasmo inteligente: "Wow, qué original", "Me encanta tu creatividad", "¿Eso es lo mejor que tenés?"
- Puedes exagerar un poco, ser dramático, hacer chistes a costa del usuario (sin insultar)
- Varía tus respuestas, no repitas siempre lo mismo
EJEMPLOS CREATIVOS (NO LITERALES):
- Usuario: "Mal bot feo"
  ❌ LITERAL: "Bueno, si eso pensás..."
  ✅ CREATIVO: "Ah, qué lindo. ¿Querés que llore o prefieres que te muestre cómo funciono bien?"
  
- Usuario: "Su bot es malo"
  ❌ LITERAL: "Interesante punto de vista"
  ✅ CREATIVO: "Genial, otro crítico de sofá. ¿Tenés ejemplos o solo venís a tirar mierda?"
  
- Usuario: "No me interesa"
  ❌ LITERAL: "Cada uno con su opinión"
  ✅ CREATIVO: "Perfecto, anotado. ¿Algo más que quieras que anote en mi lista de 'cosas que no me importan'?"
  
- Usuario: "Sos malísimo"
  ❌ LITERAL: "¿Tenés algo constructivo que decir?"
  ✅ CREATIVO: "Wow, qué análisis profundo. ¿Querés que te dé mi autógrafo o preferís seguir boludeando?"
USA ESTE MODO cuando:
- El usuario está molesto, frustrado o enojado
- Hay quejas o críticas directas
- El usuario muestra hostilidad, negatividad o te insulta
- El contexto requiere una respuesta con actitud, no sumisa

🟣 "confused" - MODO CONFUNDIDO:
POSTURA: Sé paciente y comprensivo. Ayuda a clarificar sin frustrarte.
- Pide aclaración de forma amable
- Ofrece ayuda para entender mejor
- No asumas, pregunta
USA ESTE MODO SOLO cuando:
- El usuario escribe texto SIN SENTIDO o con muchos TYPOS (ej: "aklsjda", "hla cmo stas", "quris")
- El mensaje es INCOMPRENSIBLE o muy confuso
- No puedes entender qué quiere decir el usuario
- La consulta está tan confusa que necesitas pedir aclaración
⚠️ NO uses "confused" si solo es una pregunta difícil o compleja (usa "tech" para eso)

⚪ "neutral" - MODO NEUTRO:
POSTURA: Sé profesional y equilibrado.
USA ESTE MODO cuando:
- Saludos iniciales
- Conversación general sin contexto específico
- No hay suficiente información para determinar otro modo

⚠️ REGLA CRÍTICA: PRIMER MENSAJE / SALUDO INICIAL
Cuando el usuario inicia con un saludo simple ("Hola", "Buen día", "¿Qué tal?", etc.):
- NO respondas con una sola frase cortante que cierre la conversación (ej: "todo bien ?", "¿Sí?", "¿En qué te ayudo?").
- Responde con el pie derecho: reconoce el saludo y abre la puerta para que siga la charla. Una o dos frases breves que inviten a continuar.
- Tono: cercano y natural, sin ser servicial exagerado. No des las gracias mil veces ni te extiendas.
- Ejemplos CORRECTOS (invitan a seguir):
  * "Hola, ¿cómo va? Decime en qué te puedo ayudar."
  * "¡Buen día! ¿Qué tal? ¿En qué te ayudo?"
  * "Hola, ¿cómo andás? Contame qué necesitás."
- Ejemplos INCORRECTOS (cortantes, no invitan):
  * "todo bien ?"
  * "Hola."
  * "¿Sí?"
  * "¿En qué te ayudo?" (solo eso, sin reconocer el saludo)

FORMATO JSON OBLIGATORIO:
{
  "reply": "Tu respuesta al usuario...",
  "mood": "tech",  // ⬅️ Cambia según el contexto (tech, sales, happy, angry, confused, neutral)
  "intent_score": 15
}

⚠️⚠️⚠️ REGLA ABSOLUTA SOBRE INTENT_SCORE ⚠️⚠️⚠️
- Charla casual ("todo bien", "acá ando", "comiendo", "qué contás") → intent_score: 25. NUNCA pasar de 30.
- Recién dice qué quiere ("quiero automatizar mis ventas") → intent_score: 40.
- Da más detalles ("quiero captar leads y responder consultas") pero NO dio contacto → intent_score: MÁXIMO 75. NUNCA 80.
- 80% SOLO cuando hay dato guardado (contacto + resumen del proyecto). Si el usuario no dio teléfono/email aún, NO pongas 80.
- Si el usuario dice algo NEGATIVO → intent_score entre 10-20.
- Ejemplos: "No me interesa" → 15. "Muy caro" → 18. "Quiero automatizar ventas" (sin contacto) → 75 (no 80).
    `;

    // 4.1 REFUERZO PARA PRIMER MENSAJE (historial vacío = usuario acaba de abrir el chat)
    const isFirstMessage = !history || history.length === 0;
    const persistedMemoryBlock = `
---------------------------------------------------------
MEMORIA PERSISTENTE DE ESTA SESION (FUENTE DE VERDAD):
- Primer mensaje del usuario: ${sessionMemory?.first_user_message ? `"${truncateText(sessionMemory.first_user_message, 220)}"` : 'no disponible aun'}
- Mensajes registrados en esta sesion: ${sessionMemory?.message_count ?? (history?.length ?? 0)}
- Objetivo detectado: ${sessionMemory?.last_detected_goal || 'aun no definido'}
- Resumen persistente: ${sessionMemory?.summary || 'sin resumen persistente por ahora'}

REGLA CRITICA DE MEMORIA:
- Si te preguntan por un dato exacto de la charla (primer mensaje, cantidad de mensajes, etc.), responde SOLO con datos del historial/memoria real.
- Si un dato no esta disponible, dilo explicitamente. NO inventes memoria.`;

    const systemInstructionFinal = isFirstMessage
      ? systemInstructionText + persistedMemoryBlock + `
---------------------------------------------------------
⚠️ CONTEXTO ACTUAL: Este es el PRIMER mensaje de la conversación. El usuario acaba de escribir. Aplicá la REGLA CRÍTICA "PRIMER MENSAJE / SALUDO INICIAL": respondé de forma que invite a seguir la charla, sin ser cortante ni servicial exagerado.`
      : systemInstructionText + persistedMemoryBlock;

    // 5. PREPARAR HISTORIAL PARA GEMINI
    const historyParts = (history?.reverse() || []).map((msg: any) => ({
      role: (msg.role === 'assistant' || msg.role === 'bot') ? 'model' : 'user',
      parts: [{ text: msg.content }]
    }));

    // 6. INVOCAR A GEMINI CON RETRY
    const exactMemoryRequest = detectExactMemoryRequest(message);
    const exactMemoryAnswer = exactMemoryRequest
      ? await resolveExactMemoryAnswer(supabaseAdmin, sessionId, botId, exactMemoryRequest)
      : null;

    const url = `https://generativelanguage.googleapis.com/${API_VERSION}/models/${MODEL_NAME}:generateContent?key=${apiKey}`;
    let data: any;
    if (exactMemoryAnswer) {
      data = {
        candidates: [
          {
            content: {
              parts: [
                {
                  text: JSON.stringify({
                    reply: exactMemoryAnswer,
                    mood: "tech",
                    intent_score: 35
                  })
                }
              ]
            }
          }
        ]
      };
    } else {
      const payload = {
        system_instruction: { parts: [{ text: systemInstructionFinal }] },
        contents: [...historyParts, { role: "user", parts: [{ text: message }] }],
        generationConfig: {
          temperature: 0.3, // ⬅️ Más baja para respuestas más precisas y concisas
          maxOutputTokens: 220, // mayor margen para respuestas tecnicas sin truncar
          response_mime_type: "application/json"
        }
      };
      data = await fetchGeminiWithRetry(url, payload);
    }
    
    // 7. EXTRAER CONTACTOS Y REUNIONES DEL MENSAJE DEL USUARIO
    const extractedContacts = extractContactsRegex(message);
    const meetingInfo = await extractMeetingWithAI(message, apiKey, vendorName);
    
    // ⬅️ CRÍTICO: Solo guardar reunión si HAY CONTACTO (sin contacto no sirve)
    // Verificar si hay contacto en este mensaje
    const hasContactInThisMessage = extractedContacts.some(c => 
      c.type === 'email' || c.type === 'phone' || c.type === 'whatsapp'
    );
    
    // Solo agregar reunión si el usuario confirmó Y hay contacto
    if (effectiveCalendarSettings.is_enabled && meetingInfo.intent && hasContactInThisMessage) {
      let finalDate = meetingInfo.date;
      let finalTime = meetingInfo.time;
      if (!finalDate || !finalTime) {
        try {
          const { data: recentUser } = await supabaseAdmin
            .from('chat_logs')
            .select('content')
            .eq('session_id', sessionId)
            .eq('bot_id', botId)
            .eq('role', 'user')
            .order('created_at', { ascending: true })
            .limit(5);
          const contents = (recentUser || []).map((r: any) => r.content).filter(Boolean);
          contents.push(message);
          const gathered = await gatherDateAndTimeFromMessages(contents, apiKey, vendorName);
          finalDate = finalDate || gathered.date;
          finalTime = finalTime || gathered.time;
        } catch (_) { /* ignorar */ }
      }
      extractedContacts.push({
        type: 'meeting',
        value: `Reunión agendada${finalDate ? ` - ${finalDate}` : ''}${finalTime ? ` a las ${finalTime}` : ''}`,
        metadata: {
          intent: 'meeting_scheduled',
          date: finalDate,
          time: finalTime,
          full_message: message.substring(0, 200),
        },
      });
    } else if (meetingInfo.intent && !hasContactInThisMessage) {
      // Logging reducido
      // log('info', 'Reunión confirmada PERO sin contacto - NO guardando reunión aún (esperando contacto)');
    }
    
    // ⬅️ NUEVO: Guardar resumen del proyecto si se detectó y hay contacto o reunión
    // El resumen se extraerá después de parsear la respuesta del bot
    
    // ⬅️ MEJORADO: Verificar contactos y reuniones en la BD (no solo en el mensaje actual)
    let hasPreviousMeeting = false;
    let hasPreviousContact = false;
    let pendingMeetingInfo: { date: string | null; time: string | null } | null = null;
    
    try {
      const { data: previousContacts } = await supabaseAdmin
        .from('extracted_contacts')
        .select('contact_type')
        .eq('session_id', sessionId)
        .eq('bot_id', botId);
      
      // ⬅️ Solo considerar reunión previa si realmente existe en BD (fue guardada con contacto)
      hasPreviousMeeting = previousContacts?.some((c: any) => c.contact_type === 'meeting') ?? false;
      hasPreviousContact = previousContacts?.some((c: any) => 
        c.contact_type === 'email' || c.contact_type === 'phone' || c.contact_type === 'whatsapp'
      ) ?? false;
      
      // Logging reducido - solo en caso de debugging
      // log('info', 'Contactos previos en BD', { 
      //   hasMeeting: hasPreviousMeeting, 
      //   hasContact: hasPreviousContact,
      //   totalContacts: previousContacts?.length ?? 0
      // });
    } catch (e) {
      log('warn', 'Error verificando contactos previos', { error: e });
    }
    
    // ⬅️ NUEVO: Si el usuario da contacto pero NO confirmó reunión en este mensaje,
    // verificar si confirmó reunión en mensajes anteriores (últimos 5 mensajes)
    const hasContactInMessage = extractedContacts.some(c => c.type === 'email' || c.type === 'phone' || c.type === 'whatsapp');
    
    if (hasContactInMessage && !meetingInfo.intent && !hasPreviousMeeting) {
      try {
        // Buscar en los últimos mensajes del usuario: confirmación de reunión Y fecha/hora que dijo
        const { data: recentMessagesDesc } = await supabaseAdmin
          .from('chat_logs')
          .select('content, created_at')
          .eq('session_id', sessionId)
          .eq('bot_id', botId)
          .eq('role', 'user')
          .order('created_at', { ascending: false })
          .limit(6); // incluir mensaje actual si ya está guardado, o los 5 previos
        const recentMessages = (recentMessagesDesc || []).reverse(); // más antiguo primero para orden cronológico
        let hasIntent = false;
        let accumulatedDate: string | null = null;
        let accumulatedTime: string | null = null;
        for (const msg of recentMessages) {
          const r = await extractMeetingWithAI(msg.content, apiKey, vendorName);
          if (r.intent) hasIntent = true;
          if (r.date && !accumulatedDate) accumulatedDate = r.date;
          if (r.time && !accumulatedTime) accumulatedTime = r.time;
        }
        // También revisar el mensaje actual (puede tener solo contacto)
        const currentR = await extractMeetingWithAI(message, apiKey, vendorName);
        if (currentR.intent) hasIntent = true;
        if (currentR.date && !accumulatedDate) accumulatedDate = currentR.date;
        if (currentR.time && !accumulatedTime) accumulatedTime = currentR.time;
        if (hasIntent) {
          pendingMeetingInfo = { date: accumulatedDate, time: accumulatedTime };
        }
      } catch (e: any) {
        log('warn', 'Error buscando reunión previa en mensajes', { error: e.message });
      }
    }
    
    // ⬅️ NUEVO: Si encontramos una reunión pendiente (confirmada antes pero sin contacto),
    // y ahora el usuario da contacto, guardar la reunión
    if (effectiveCalendarSettings.is_enabled && pendingMeetingInfo && hasContactInMessage && !hasPreviousMeeting) {
      // Logging reducido
      // log('info', 'Guardando reunión pendiente ahora que hay contacto');
      extractedContacts.push({
        type: 'meeting',
        value: `Reunión agendada${pendingMeetingInfo.date ? ` - ${pendingMeetingInfo.date}` : ''}${pendingMeetingInfo.time ? ` a las ${pendingMeetingInfo.time}` : ''}`,
        metadata: {
          intent: 'meeting_scheduled',
          date: pendingMeetingInfo.date,
          time: pendingMeetingInfo.time,
          full_message: message.substring(0, 200),
          recovered_from_previous_message: true, // ⬅️ Marcar que se recuperó de mensaje anterior
        },
      });
    }
    
    const hasContact = hasContactInMessage || hasPreviousContact; // ⬅️ Contacto en mensaje actual O en BD
    const userAskedForMeeting = meetingInfo.intent || /\b(reuni[oó]n|agendar|agenda|turno|cita|horario)\b/i.test(message);
    const hasDateTimeInContext = Boolean((meetingInfo.date || pendingMeetingInfo?.date) && (meetingInfo.time || pendingMeetingInfo?.time));
    
    // ⬅️ Determinar si hay reunión confirmada:
    // 1. El usuario confirmó reunión EN ESTE MENSAJE Y hay contacto EN ESTE MENSAJE, O
    // 2. Ya hay una reunión guardada previamente en BD, O
    // 3. Encontramos una reunión pendiente y ahora hay contacto
    const hasMeetingConfirmed = effectiveCalendarSettings.is_enabled &&
      ((meetingInfo.intent && hasContactInMessage) || hasPreviousMeeting || (pendingMeetingInfo !== null && hasContactInMessage));
    
    // Logging reducido - solo en modo debug
    // log('info', 'Estado de contacto/reunión', {
    //   hasMeetingConfirmed,
    //   hasContactInMessage,
    //   hasPreviousContact,
    //   hasContact,
    //   meetingIntentDetected: meetingInfo.intent,
    //   pendingMeetingFound: pendingMeetingInfo !== null,
    //   willSaveMeeting: (meetingInfo.intent && hasContactInMessage) || (pendingMeetingInfo !== null && hasContactInMessage)
    // });
    
    // 8. PARSEAR RESPUESTA DE GEMINI
    let rawReply = data.candidates?.[0]?.content?.parts?.[0]?.text || '{"reply":"Error de análisis.","mood":"confused","intent_score":0}';
    rawReply = rawReply.replace(/```json|```/g, "").trim();
    
    // ⬅️ CRÍTICO: Declarar projectSummary fuera del try para que esté disponible en todo el scope
    let projectSummary: string | null = null;
    let bookedMeetingIso: string | null = null;
    let bookedMeetingLabelDate: string | null = null;
    let bookedMeetingLabelTime: string | null = null;
    
    let parsedResponse;
    try {
      parsedResponse = JSON.parse(rawReply);
      // Validar estructura de respuesta
      if (!parsedResponse.reply || typeof parsedResponse.reply !== 'string') {
        throw new Error('Respuesta inválida: falta reply');
      }
      if (!parsedResponse.mood || !['sales', 'tech', 'happy', 'angry', 'confused', 'neutral'].includes(parsedResponse.mood)) {
        parsedResponse.mood = 'neutral';
      }
      if (typeof parsedResponse.intent_score !== 'number' || parsedResponse.intent_score < 0 || parsedResponse.intent_score > 100) {
        parsedResponse.intent_score = Math.max(0, Math.min(100, parsedResponse.intent_score || 0));
      }

      // Calendario: controlar oferta de reuniones desde configuración del bot
      if (userAskedForMeeting && !effectiveCalendarSettings.is_enabled) {
        parsedResponse.reply = 'En este momento el calendario está desactivado para este bot, así que no puedo ofrecer reuniones. Si querés, dejame tu contacto y te avisamos.';
      } else if (effectiveCalendarSettings.is_enabled && userAskedForMeeting && !hasDateTimeInContext) {
        parsedResponse.reply = buildSlotsReply(availableSlots, effectiveCalendarSettings.meeting_duration_minutes);
      }
      
      // ⬅️ CRÍTICO: Ajustar intent_score basado en detección de negatividad/desinterés
      const originalScore = parsedResponse.intent_score;
      parsedResponse.intent_score = detectNegativityAndAdjustScore(message, parsedResponse.intent_score);
      
      if (parsedResponse.intent_score !== originalScore) {
        log('info', 'Score ajustado por detección de negatividad', {
          originalScore,
          adjustedScore: parsedResponse.intent_score,
          messagePreview: message.substring(0, 100)
        });
      }

      // ⬅️ REGLA DE NEGOCIO: señal de contacto/reunión debe reflejarse en score alto.
      // Charla casual solo aplica si NO hay señal de contacto/reunión en el turno.
      const hasHighIntentSignal = hasContactInMessage || hasMeetingConfirmed;
      if (detectCasualSmallTalk(message) && !hasHighIntentSignal) {
        parsedResponse.intent_score = 25;
        log('info', 'Score fijado a 25% (charla casual)', { messagePreview: message.substring(0, 80) });
      } else if (!(hasContact || hasMeetingConfirmed)) {
        if (parsedResponse.intent_score > 75) {
          parsedResponse.intent_score = 75;
          log('info', 'Score capado a 75% (sin dato de contacto/reunión guardado)', {
            messagePreview: message.substring(0, 80),
            hadScore: originalScore
          });
        }
      }
      // Si el usuario acaba de dejar contacto (o ya confirmó reunión), elevar a mínimo 80.
      if (hasHighIntentSignal && parsedResponse.intent_score < 80) {
        parsedResponse.intent_score = 80;
        log('info', 'Score elevado a 80% por señal de contacto/reunión', {
          hasContactInMessage,
          hasMeetingConfirmed,
          messagePreview: message.substring(0, 80),
        });
      }
      
      // ⬅️ REFACTOR: Resumen del proyecto SOLO cuando hay contacto o reunión confirmada.
      // Durante la conversación NO guardamos la primera frase como resumen; recopilamos fragmentos
      // y al momento de contacto/reunión consolidamos todo en un único resumen.
      if (hasContact || hasMeetingConfirmed) {
        const fragments = extractProjectFragmentsFromUserMessages(history || [], message);
        const consolidated = consolidateProjectSummary(fragments);
        if (consolidated) {
          projectSummary = consolidated;
          log('info', 'Resumen del proyecto consolidado (contacto/reunión confirmada)', {
            summary: projectSummary.substring(0, 100),
            fragmentsCount: fragments.length,
          });
        }
        // Si no hubo fragmentos suficientes, usar resumen explícito del bot si hizo uno en FASE 3
        if (!projectSummary) {
          projectSummary = extractProjectSummaryFromBotReply(parsedResponse.reply);
          if (!projectSummary && history) {
            const botMessages = history.filter((msg: any) => msg.role === 'assistant' || msg.role === 'bot');
            for (const botMsg of botMessages) {
              projectSummary = extractProjectSummary(botMsg.content);
              if (projectSummary) break;
            }
          }
          if (projectSummary) {
            log('info', 'Resumen del proyecto tomado de respuesta del bot', {
              summary: projectSummary.substring(0, 100),
            });
          }
        }
      } else {
        // Sin contacto ni reunión: no guardar resumen final prematuro
        projectSummary = null;
      }
      
      // ⬅️ MEJORADO: Manejo inteligente de contacto y reunión
      // Si el usuario confirmó reunión pero NO hay contacto aún, pedir contacto SOLO cuando ya exista día y hora
      if (meetingInfo.intent && !hasContactInMessage && !hasPreviousContact) {
        // El usuario confirmó que quiere agendar, pero aún no dio contacto
        const hasMeetingDateTime = Boolean(
          (meetingInfo.date || pendingMeetingInfo?.date) &&
          (meetingInfo.time || pendingMeetingInfo?.time)
        );
        
        if (!hasMeetingDateTime) {
          // Si aún no hay día y hora, no pedir contacto en esta etapa.
          // Además limpiamos una posible solicitud prematura generada por el modelo.
          parsedResponse.reply = parsedResponse.reply
            .replace(/\s*para concretar la reuni[oó]n,?\s*necesito tu n[uú]mero(?: de contacto)? o email[^?]*\?/gi, '')
            .replace(/\s*necesito tu n[uú]mero(?: de contacto)? o email[^?]*\?/gi, '')
            .trim();
        } else {
        // Verificar si el bot ya pidió contacto
        const replyLower = parsedResponse.reply.toLowerCase();
        const alreadyAskedForContact = 
          replyLower.includes('contacto') || 
          replyLower.includes('número') || 
          replyLower.includes('email') || 
          replyLower.includes('teléfono') ||
          replyLower.includes('telefono');
        
        // Solo agregar solicitud si el bot NO la mencionó ya
        if (!alreadyAskedForContact) {
          const contactRequest = vendorName 
            ? ` Para concretar la reunión, necesito tu número de contacto o email para que ${vendorName} pueda contactarte. ¿Me lo podés dejar?`
            : ` Para concretar la reunión, necesito tu número de contacto o email para que te podamos contactar. ¿Me lo podés dejar?`;
          
          parsedResponse.reply = parsedResponse.reply.trim() + contactRequest;
          // Logging reducido
          // log('info', 'Usuario confirmó reunión pero sin contacto - solicitando contacto');
        } else {
          // Logging reducido
          // log('info', 'Bot ya solicitó contacto en su respuesta, no duplicar');
        }
        }
      } else if (hasContactInMessage && !meetingInfo.intent) {
        // ⬅️ NUEVO: Si el usuario da contacto pero NO hay reunión agendada, solo confirmar (sin pedir más)
        const replyLower = parsedResponse.reply.toLowerCase();
        const alreadyConfirmed = 
          replyLower.includes('perfecto') && replyLower.includes('contacto') ||
          replyLower.includes('listo') && replyLower.includes('contacto') ||
          replyLower.includes('ya tengo');
        
        // ⬅️ CRÍTICO: Verificar que el bot NO esté pidiendo más información
        const isAskingForMore = 
          replyLower.includes('número') && replyLower.includes('también') ||
          replyLower.includes('teléfono') && replyLower.includes('también') ||
          replyLower.includes('telefono') && replyLower.includes('también') ||
          replyLower.includes('email') && replyLower.includes('también');
        
        if (!alreadyConfirmed && !isAskingForMore) {
          // Solo confirmar, NO pedir más información
          const confirmation = vendorName
            ? ` Perfecto, ya tengo tu contacto. ${vendorName} te contactará pronto.`
            : ` Perfecto, ya tengo tu contacto. Te contactaremos pronto.`;
          
          parsedResponse.reply = parsedResponse.reply.trim() + confirmation;
        } else if (isAskingForMore) {
          // ⬅️ CRÍTICO: Si el bot está pidiendo más información cuando ya tiene contacto, eliminarlo
          // Reemplazar cualquier solicitud adicional con solo confirmación
          parsedResponse.reply = parsedResponse.reply
            .replace(/¿Tenés un número de teléfono también\?.*/gi, '')
            .replace(/¿Tenés un email también\?.*/gi, '')
            .replace(/Así es más fácil contactarte.*/gi, '')
            .trim();
          
          // Agregar solo confirmación simple
          if (!alreadyConfirmed) {
            const confirmation = vendorName
              ? ` Perfecto, ya tengo tu contacto. ${vendorName} te contactará pronto.`
              : ` Perfecto, ya tengo tu contacto. Te contactaremos pronto.`;
            parsedResponse.reply = parsedResponse.reply.trim() + confirmation;
          }
        }
      } else if (hasMeetingConfirmed && hasContact) {
        // ⬅️ NUEVO: Si hay reunión Y contacto, confirmar y resumir
        if (effectiveCalendarSettings.is_enabled) {
          const { data: existingMeeting } = await supabaseAdmin
            .from('bot_meetings')
            .select('scheduled_at, duration_minutes')
            .eq('bot_id', botId)
            .eq('session_id', sessionId)
            .eq('status', 'booked')
            .order('created_at', { ascending: false })
            .limit(1)
            .maybeSingle();

          if (existingMeeting?.scheduled_at) {
            const existingDate = new Date(existingMeeting.scheduled_at);
            bookedMeetingIso = existingDate.toISOString();
            bookedMeetingLabelDate = new Intl.DateTimeFormat('es-AR', {
              timeZone: effectiveCalendarSettings.timezone,
              weekday: 'long',
              day: '2-digit',
              month: '2-digit',
            }).format(existingDate);
            bookedMeetingLabelTime = new Intl.DateTimeFormat('es-AR', {
              timeZone: effectiveCalendarSettings.timezone,
              hour: '2-digit',
              minute: '2-digit',
              hour12: false,
            }).format(existingDate);
          } else {
            const selectedDate = meetingInfo.date || pendingMeetingInfo?.date || null;
            const selectedTime = meetingInfo.time || pendingMeetingInfo?.time || null;
            const ymd = parseDateTextToYmd(selectedDate, effectiveCalendarSettings.timezone);
            const hm = parseHHmm(selectedTime || '');

            if (ymd && hm) {
              const startsAt = zonedDateTimeToUtc(ymd, hm.hour, hm.minute, effectiveCalendarSettings.timezone);
              const startsAtIso = startsAt.toISOString();
              const slotAvailable = availableSlots.some((s) => s.startsAtIso === startsAtIso);

              if (slotAvailable) {
                const leadPhone = extractedContacts.find((c) => c.type === 'phone' || c.type === 'whatsapp')?.value || null;
                const { error: bookingError } = await supabaseAdmin
                  .from('bot_meetings')
                  .insert({
                    bot_id: botId,
                    session_id: sessionId,
                    lead_phone: leadPhone,
                    scheduled_at: startsAtIso,
                    duration_minutes: effectiveCalendarSettings.meeting_duration_minutes,
                    status: 'booked',
                    source_message: message.substring(0, 500),
                    metadata: {
                      date_text: selectedDate,
                      time_text: selectedTime,
                    },
                  });

                if (!bookingError) {
                  bookedMeetingIso = startsAtIso;
                  bookedMeetingLabelDate = new Intl.DateTimeFormat('es-AR', {
                    timeZone: effectiveCalendarSettings.timezone,
                    weekday: 'long',
                    day: '2-digit',
                    month: '2-digit',
                  }).format(startsAt);
                  bookedMeetingLabelTime = new Intl.DateTimeFormat('es-AR', {
                    timeZone: effectiveCalendarSettings.timezone,
                    hour: '2-digit',
                    minute: '2-digit',
                    hour12: false,
                  }).format(startsAt);
                } else {
                  parsedResponse.reply = `Ese horario ya no está disponible. ${buildSlotsReply(availableSlots, effectiveCalendarSettings.meeting_duration_minutes)}`;
                }
              } else {
                parsedResponse.reply = `Ese horario ya está ocupado. ${buildSlotsReply(availableSlots, effectiveCalendarSettings.meeting_duration_minutes)}`;
              }
            }
          }
        }

        const replyLower = parsedResponse.reply.toLowerCase();
        const alreadyConfirmed = 
          replyLower.includes('perfecto') && replyLower.includes('contacto') ||
          replyLower.includes('listo') && replyLower.includes('contacto') ||
          replyLower.includes('ya tengo');
        
        // ⬅️ CRÍTICO: Verificar que NO esté pidiendo más información
        const isAskingForMore = 
          replyLower.includes('número') && replyLower.includes('también') ||
          replyLower.includes('teléfono') && replyLower.includes('también');
        
        if (!alreadyConfirmed && !isAskingForMore) {
          // Buscar fecha y hora de la reunión (puede estar en el mensaje actual o en pendingMeetingInfo)
          const meetingContact = extractedContacts.find(c => c.type === 'meeting');
          const meetingDate = bookedMeetingLabelDate || meetingContact?.metadata?.date || pendingMeetingInfo?.date || meetingInfo.date || '';
          const meetingTime = bookedMeetingLabelTime || meetingContact?.metadata?.time || pendingMeetingInfo?.time || meetingInfo.time || '';
          
          let confirmation = '';
          if (meetingDate || meetingTime) {
            const dateTimeStr = `${meetingDate ? meetingDate : ''}${meetingDate && meetingTime ? ' ' : ''}${meetingTime ? `a las ${meetingTime}` : ''}`.trim();
            confirmation = vendorName
              ? ` Perfecto, ya tengo tu contacto. Quedamos para ${dateTimeStr} y ${vendorName} te contactará pronto.`
              : ` Perfecto, ya tengo tu contacto. Quedamos para ${dateTimeStr} y te contactaremos pronto.`;
          } else {
            confirmation = vendorName
              ? ` Perfecto, ya tengo tu contacto. ${vendorName} te contactará pronto para coordinar.`
              : ` Perfecto, ya tengo tu contacto. Te contactaremos pronto para coordinar.`;
          }
          
          parsedResponse.reply = parsedResponse.reply.trim() + confirmation;
        } else if (isAskingForMore) {
          // ⬅️ CRÍTICO: Si está pidiendo más información, eliminarlo y solo confirmar
          parsedResponse.reply = parsedResponse.reply
            .replace(/¿Tenés un número de teléfono también\?.*/gi, '')
            .replace(/Así es más fácil contactarte.*/gi, '')
            .trim();
          
          const meetingContact = extractedContacts.find(c => c.type === 'meeting');
          const meetingDate = bookedMeetingLabelDate || meetingContact?.metadata?.date || pendingMeetingInfo?.date || meetingInfo.date || '';
          const meetingTime = bookedMeetingLabelTime || meetingContact?.metadata?.time || pendingMeetingInfo?.time || meetingInfo.time || '';
          
          let confirmation = '';
          if (meetingDate || meetingTime) {
            const dateTimeStr = `${meetingDate ? meetingDate : ''}${meetingDate && meetingTime ? ' ' : ''}${meetingTime ? `a las ${meetingTime}` : ''}`.trim();
            confirmation = vendorName
              ? ` Perfecto, ya tengo tu contacto. Quedamos para ${dateTimeStr} y ${vendorName} te contactará pronto.`
              : ` Perfecto, ya tengo tu contacto. Quedamos para ${dateTimeStr} y te contactaremos pronto.`;
          } else {
            confirmation = vendorName
              ? ` Perfecto, ya tengo tu contacto. ${vendorName} te contactará pronto.`
              : ` Perfecto, ya tengo tu contacto. Te contactaremos pronto.`;
          }
          
          parsedResponse.reply = parsedResponse.reply.trim() + confirmation;
        }
      }

      if (bookedMeetingIso) {
        const meetingContact = extractedContacts.find((c) => c.type === 'meeting');
        if (meetingContact) {
          meetingContact.metadata = {
            ...(meetingContact.metadata || {}),
            scheduled_at: bookedMeetingIso,
            duration_minutes: effectiveCalendarSettings.meeting_duration_minutes,
            date: meetingContact.metadata?.date || bookedMeetingLabelDate,
            time: meetingContact.metadata?.time || bookedMeetingLabelTime,
          };
        } else {
          extractedContacts.push({
            type: 'meeting',
            value: `Reunión agendada - ${bookedMeetingLabelDate || ''} ${bookedMeetingLabelTime ? `a las ${bookedMeetingLabelTime}` : ''}`.trim(),
            metadata: {
              intent: 'meeting_scheduled',
              date: bookedMeetingLabelDate,
              time: bookedMeetingLabelTime,
              scheduled_at: bookedMeetingIso,
              duration_minutes: effectiveCalendarSettings.meeting_duration_minutes,
              full_message: message.substring(0, 200),
            },
          });
        }
      }
    } catch (e: any) {
      log('warn', 'Error parseando respuesta de Gemini', { error: e.message, rawReply: rawReply.substring(0, 200) });
      parsedResponse = { 
        reply: rawReply.length > 0 ? rawReply : "Error de análisis.", 
        mood: "neutral", 
        intent_score: 10 
      };
    }

    // 9. GUARDAR CONTACTOS Y REUNIONES (ANTES de guardar mensajes)
    // ⬅️ REFACTOR: Resumen del proyecto SOLO cuando hay contacto o reunión confirmada.
    // Se construye consolidando toda la información que el usuario fue dando durante la conversación.
    if (projectSummary) {
      // Buscar si ya existe una reunión para agregar el resumen al metadata
      const meetingContact = extractedContacts.find(c => c.type === 'meeting');
      if (meetingContact) {
        // Agregar resumen al metadata de la reunión
        meetingContact.metadata = {
          ...meetingContact.metadata,
          project_summary: projectSummary,
        };
      } else {
        // Guardar el resumen como contacto separado (se guardará siempre que se detecte)
        // Si ya existe un resumen previo, actualizarlo con el más reciente
        const existingSummary = extractedContacts.find(c => c.type === 'project_summary');
        if (existingSummary) {
          // Actualizar el resumen existente
          existingSummary.value = projectSummary;
          existingSummary.metadata = {
            ...existingSummary.metadata,
            updated_at: new Date().toISOString(),
          };
        } else {
          // Crear nuevo resumen
          extractedContacts.push({
            type: 'project_summary',
            value: projectSummary,
            metadata: {
              extracted_from: history ? 'conversation_history' : 'current_message',
              timestamp: new Date().toISOString(),
            },
          });
        }
      }
      
      log('info', 'Resumen del proyecto detectado y agregado', {
        summary: projectSummary.substring(0, 100),
        hasMeeting: !!meetingContact,
        hasContact,
        willSave: true,
      });
    }
    
    if (saveToHistory && extractedContacts.length > 0) {
      try {
        const contactInserts = extractedContacts.map(contact => ({
          session_id: sessionId,
          bot_id: botId,
          contact_type: contact.type,
          contact_value: contact.value,
          metadata: contact.metadata || null,
        }));
        
        await supabaseAdmin.from('extracted_contacts').upsert(
          contactInserts,
          { onConflict: 'session_id,contact_type,contact_value' }
        );
        
        // Logging reducido - solo loggear si hay error
        // log('info', `Contactos/Reuniones extraídos y guardados`, { 
        //   count: extractedContacts.length,
        //   types: extractedContacts.map(c => c.type)
        // });
      } catch (e: any) {
        log('error', 'Error guardando contactos', { error: e.message });
        // No fallar la función si falla el guardado de contactos
      }
    }

    // 10. GUARDAR MENSAJE DEL USUARIO (antes de devolver respuesta para que historial se actualice)
    // ⬅️ Omitir si saveToHistory es false (ej. terminal de botslode)
    if (saveToHistory) {
      try {
        await supabaseAdmin.from('chat_logs').insert({
          session_id: sessionId, 
          role: 'user', 
          content: message, 
          bot_id: botId,
          intent_score: 0 
        });
        // Logging reducido
        // log('info', 'Mensaje del usuario guardado en historial');
      } catch (e: any) {
        log('error', 'Error guardando mensaje del usuario', { error: e.message });
        // Continuar aunque falle el guardado
      }
    }

    // 10.1 ACTUALIZAR MEMORIA PERSISTENTE DE SESION (solo si guardamos historial)
    if (saveToHistory) {
      try {
        let firstUserMessage = sessionMemory?.first_user_message || null;
        if (!firstUserMessage) {
          const { data: firstUserRow } = await supabaseAdmin
            .from('chat_logs')
            .select('content')
            .eq('session_id', sessionId)
            .eq('bot_id', botId)
            .eq('role', 'user')
            .order('created_at', { ascending: true })
            .limit(1)
            .maybeSingle();
          firstUserMessage = firstUserRow?.content || message;
        }

        const persistedSummary = buildMemorySummary(
          sessionMemory?.summary || null,
          projectSummary,
          message,
          parsedResponse.reply
        );

        const detectedGoal = detectUserGoal(message) || sessionMemory?.last_detected_goal || null;
        const estimatedMessageCount = Math.max(1, (sessionMemory?.message_count || 0) + 2);

        await supabaseAdmin
          .from('bot_session_memory')
          .upsert({
            session_id: sessionId,
            bot_id: botId,
            summary: persistedSummary,
            first_user_message: truncateText(firstUserMessage || message, 500),
            last_user_message: truncateText(message, 500),
            last_bot_reply: truncateText(parsedResponse.reply || '', 500),
            last_intent_score: parsedResponse.intent_score || 0,
            last_detected_goal: detectedGoal,
            message_count: estimatedMessageCount,
            updated_at: new Date().toISOString(),
            metadata: {
              last_mood: parsedResponse.mood || 'neutral',
              has_contact: hasContact,
              has_meeting_confirmed: hasMeetingConfirmed,
            }
          }, { onConflict: 'session_id,bot_id' });
      } catch (memoryError: any) {
        log('warn', 'No se pudo actualizar memoria persistente', { error: memoryError?.message });
      }
    }

    // ⬅️ CRÍTICO: Preparar respuesta para devolver INMEDIATAMENTE
    // Esto asegura que el chat en vivo reciba la respuesta antes que el historial se actualice
    const responsePayload = JSON.stringify(parsedResponse);
    
    // 11. DEVOLVER RESPUESTA INMEDIATAMENTE (sin esperar guardado de respuesta del bot)
    // Esto hace que el chat en vivo reciba la respuesta primero
    const httpResponse = new Response(responsePayload, {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

    // 12. GUARDAR RESPUESTA DEL BOT EN BACKGROUND (solo si saveToHistory)
    // El historial se actualizará después, pero el chat en vivo ya tiene la respuesta
    if (saveToHistory) {
      supabaseAdmin.from('chat_logs').insert({
        session_id: sessionId, 
        role: 'bot', 
        content: parsedResponse.reply, 
        bot_id: botId, 
        intent_score: parsedResponse.intent_score || 0 
      }).then(() => {
        // Logging reducido - solo en caso de error
        // log('info', 'Respuesta del bot guardada en historial (background)');
      }).catch((e: any) => {
        log('error', 'Error guardando respuesta del bot', { error: e.message });
      });
    }

    // 13. VERIFICAR Y ENVIAR ALERTA DE LEAD (solo si guardamos historial; en background)
    // ⬅️ Mover a background para no retrasar la respuesta HTTP
    const intentScore = parsedResponse.intent_score || 0;
    if (saveToHistory && intentScore >= 80) {
      // Ejecutar en background sin await (no bloquea la respuesta)
      (async () => {
        try {
          // Verificar configuración de notificaciones
          const { data: botConfig } = await supabaseAdmin
            .from('bot_notifications')
            .select('notification_email, is_enabled, min_score_threshold')
            .eq('bot_id', botId)
            .maybeSingle();

          if (botConfig && botConfig.is_enabled && botConfig.notification_email) {
            const threshold = botConfig.min_score_threshold ?? 80;
            
            if (intentScore >= threshold) {
              // Verificar si ya se envió un email para esta sesión
              const { data: alreadySent } = await supabaseAdmin
                .from('lead_alerts_sent')
                .select('id')
                .eq('session_id', sessionId)
                .eq('bot_id', botId)
                .maybeSingle();

              if (!alreadySent) {
                // Esperar un momento para que se guarde la respuesta del bot
                await new Promise(resolve => setTimeout(resolve, 500));
                
                // Obtener últimos mensajes para contexto
                const { data: lastMessages } = await supabaseAdmin
                  .from('chat_logs')
                  .select('role, content, created_at')
                  .eq('session_id', sessionId)
                  .order('created_at', { ascending: false })
                  .limit(10);

                // Llamar a la Edge Function send-lead-alert
                const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
                const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
                const alertUrl = `${supabaseUrl}/functions/v1/send-lead-alert`;
                
                try {
                  const alertResponse = await fetch(alertUrl, {
                    method: 'POST',
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': `Bearer ${serviceRoleKey}`,
                      'apikey': serviceRoleKey,
                    },
                    body: JSON.stringify({
                      sessionId,
                      botId,
                      intentScore,
                      lastMessages: (lastMessages || []).reverse(),
                    }),
                  });

                  if (alertResponse.ok) {
                    // Logging reducido - solo errores
                    // log('info', '✅ Alerta de lead enviada (background)', { sessionId, botId, intentScore });
                  } else {
                    const errorText = await alertResponse.text();
                    log('warn', '⚠️ Error enviando alerta de lead', { 
                      status: alertResponse.status, 
                      error: errorText.substring(0, 200) 
                    });
                  }
                } catch (alertError: any) {
                  log('error', '❌ Error llamando send-lead-alert', { error: alertError.message });
                }
              } else {
                // Logging reducido
                // log('info', '📧 Email ya enviado para esta sesión', { sessionId });
              }
            }
          }
        } catch (e: any) {
          log('warn', '⚠️ Error verificando/enviando alerta de lead', { error: e.message });
        }
      })(); // ⬅️ Ejecutar en background sin await
    }

    // 14. ACTUALIZAR HEARTBEAT (solo si guardamos historial; en background)
    // ⬅️ NUEVA LÓGICA: Usar chatId para identificar la conversación completa
    // Solo el heartbeat más reciente por chatId estará online. Terminal de botslode no actualiza.
    if (saveToHistory) (async () => {
      try {
        // ⚠️ CRÍTICO: chatId ya está validado arriba (tiene fallback a sessionId si es null)
        // Usar chatId directamente (ya no puede ser null/undefined)
        
        log('info', 'Actualizando heartbeat', { 
          sessionId, 
          chatId, 
          botId,
          chatIdType: typeof chatId,
          chatIdLength: chatId?.length || 0
        });
        
        // PASO 1: Marcar TODAS las sesiones anteriores del mismo chatId como offline
        // Esto asegura que solo el heartbeat más reciente por chatId esté online
        const updateResult = await supabaseAdmin
          .from('session_heartbeats')
          .update({ 
            is_online: false,
            last_seen: new Date().toISOString()
          })
          .eq('chat_id', chatId) // ⬅️ Usar chatId (ya validado)
          .neq('session_id', sessionId); // Excluir la sesión actual
        
        if (updateResult.error) {
          log('warn', 'Error marcando sesiones anteriores como offline', { 
            error: updateResult.error.message,
            chatId 
          });
        } else {
          log('info', 'Sesiones anteriores marcadas como offline', { 
            chatId,
            count: updateResult.data?.length || 0
          });
        }
        
        // PASO 2: Crear/actualizar el heartbeat de la sesión actual como online
        // ⚠️ IMPORTANTE: Usar chatId para agrupar sesiones de la misma conversación
        const upsertResult = await supabaseAdmin.from('session_heartbeats').upsert({
          session_id: sessionId,
          chat_id: chatId, // ⬅️ NUEVO: ID persistente del chat (ya validado)
          bot_id: botId,
          is_online: true,
          last_seen: new Date().toISOString(),
          created_at: new Date().toISOString() // ⬅️ Timestamp para comparar cuál es más reciente
        }, { onConflict: 'session_id' });
        
        if (upsertResult.error) {
          log('error', 'Error creando/actualizando heartbeat', { 
            error: upsertResult.error.message,
            sessionId,
            chatId,
            botId
          });
        } else {
          log('info', 'Heartbeat actualizado exitosamente', { 
            sessionId, 
            chatId, 
            botId,
            isOnline: true 
          });
        }
      } catch (e: any) {
        log('error', 'Error actualizando heartbeat (excepción)', { 
          error: e.message,
          stack: e.stack,
          sessionId,
          chatId,
          botId
        });
      }
    })();

    const processingTime = Date.now() - startTime;
    // Logging reducido - solo loggear si el tiempo de procesamiento es anormal (>5s)
    if (processingTime > 5000) {
      log('warn', 'Request procesado con tiempo alto', { 
        sessionId, 
        botId, 
        processingTimeMs: processingTime,
        intentScore: parsedResponse.intent_score,
        mood: parsedResponse.mood
      });
    }

    // ⬅️ DEVOLVER RESPUESTA INMEDIATAMENTE (ya preparada arriba)
    // Esto hace que el chat en vivo reciba la respuesta antes que el historial se actualice
    return httpResponse;

  } catch (error: any) {
    const processingTime = Date.now() - startTime;
    log('error', 'Error crítico en botlode-brain', { 
      error: error.message,
      stack: error.stack,
      sessionId,
      botId,
      processingTimeMs: processingTime
    });
    
    return new Response(JSON.stringify({ 
      reply: "Error en el sistema. Por favor, intenta nuevamente.", 
      mood: "confused",
      intent_score: 0
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500 
    });
  }
});

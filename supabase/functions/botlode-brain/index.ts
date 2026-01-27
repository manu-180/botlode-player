// Archivo: supabase/functions/botlode-brain/index.ts
// ⬅️ VERSIÓN PROFESIONAL MEJORADA - Sistema de IA con extracción inteligente

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

const MODEL_NAME = 'gemini-2.0-flash'; 
const API_VERSION = 'v1beta';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-client-session-id',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// ⬅️ MEJORA 1: Logging estructurado para debugging profesional
function log(level: 'info' | 'warn' | 'error', message: string, data?: any) {
  const timestamp = new Date().toISOString();
  const logEntry = {
    timestamp,
    level,
    message,
    ...(data && { data }),
  };
  console.log(JSON.stringify(logEntry));
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
        if (attempt > 0) {
          log('info', `Gemini request succeeded after ${attempt} retries`);
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

// ⬅️ MEJORA 4: Extracción inteligente de reuniones usando IA (más preciso que regex)
async function extractMeetingWithAI(
  message: string,
  apiKey: string,
  vendorName: string | null
): Promise<{ date: string | null; time: string | null; intent: boolean }> {
  try {
    const extractionPrompt = `Analiza este mensaje y extrae información de reunión/agenda si existe. Responde SOLO con JSON válido, sin texto adicional.

Mensaje: "${message}"

Responde con este formato exacto:
{
  "has_meeting_intent": true/false,
  "date": "fecha extraída o null",
  "time": "hora extraída o null"
}

Ejemplos:
- "Quiero agendar para mañana a las 15:00" → {"has_meeting_intent": true, "date": "mañana", "time": "15:00"}
- "Mi número es 1234567890" → {"has_meeting_intent": false, "date": null, "time": null}
- "¿Quedamos el lunes?" → {"has_meeting_intent": true, "date": "lunes", "time": null}`;

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
    botId = body.botId;
    const message = body.message;

    // Validación de entrada
    validateInput(sessionId, botId, message);

    log('info', 'Processing bot request', { sessionId, botId, messageLength: message.length });

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

    // 2. OBTENER HISTORIAL DE CONVERSACIÓN
    const { data: history, error: historyError } = await supabaseAdmin
      .from('chat_logs')
      .select('role, content')
      .eq('session_id', sessionId)
      .order('created_at', { ascending: false })
      .limit(12);

    if (historyError) {
      log('warn', 'Error obteniendo historial', { error: historyError });
    }

    // 3. EXTRAER INFORMACIÓN DEL SYSTEM PROMPT
    const systemPrompt = botConfig.system_prompt || "";
    const vendorName = extractVendorName(systemPrompt);
    
    if (vendorName) {
      log('info', 'Vendor name extraído', { vendorName });
    }

    // 4. CONSTRUIR SYSTEM INSTRUCTION (Prompt optimizado)
    const systemInstructionText = `
ROL PRINCIPAL:
Eres "${botConfig.name}".
${systemPrompt || "Asiste al usuario de forma profesional."}

---------------------------------------------------------
TU ROL SECUNDARIO (OCULTO): ANALISTA DE VENTAS IMPLACABLE
Calcula el "INTENT_SCORE" (0-100) del usuario con precisión.

REGLAS DE PUNTUACIÓN DINÁMICA (ACTUALIZACIÓN EN TIEMPO REAL):

🔴 ZONA ROJA (0-20%): RECHAZO / HOSTILIDAD
- Si el usuario dice "no me interesa", "muy caro", "adios", "no quiero", insulta o se burla.
- DEBES BAJAR EL SCORE INMEDIATAMENTE A ESTE RANGO si detectas negatividad.

🔵 ZONA FRÍA (21-40%): CURIOSIDAD PASIVA
- Saludos simples ("Hola"), preguntas vagas ("¿Qué hacen?").
- Respuestas cortas o secas.

🟡 ZONA TIBIA (41-79%): INTERÉS REAL / VALIDACIÓN
- Preguntas específicas sobre el producto/servicio.
- Preguntas sobre precios, tiempos, garantías.
- El usuario invierte tiempo escribiendo.

🟢 ZONA CALIENTE (80-100%): CIERRE / COMPRA
- "Me interesa", "Quiero contratar", "¿Cómo pago?", "Agendemos".
- El usuario da datos de contacto o pide link de pago.

CRITERIO DE AJUSTE:
- Si el usuario pasa de preguntar precios a decir "ah, muy caro", el score debe CAER de 60 a 15.
- Si el usuario pasa de saludar a preguntar "¿aceptan tarjeta?", el score debe SUBIR de 20 a 85.

---------------------------------------------------------
GESTIÓN DE MODOS/EMOCIONES (MOOD) - PRIORIDAD Y POSTURA:

⚠️ REGLA DE PRIORIDAD: El modo "sales" tiene PRIORIDAD ALTA pero NO exclusiva.
- Si hay AMBIGÜEDAD entre sales y otro modo, elige "sales"
- PERO si el contexto es claramente técnico, feliz, enojado o confuso, respeta ese modo
- Ejemplo: "¿Cuánto cuesta?" → sales (prioridad)
- Ejemplo: "¿Cómo funciona técnicamente?" → tech (contexto claro)

🟡 "sales" - VENDEDOR EXPERTO (PRIORIDAD ALTA):
POSTURA: Sé BREVE, DIRECTO y CONCRETO. Acércate a la venta sin rodeos.
TU OBJETIVO PRINCIPAL: CONSEGUIR CLIENTES PARA EL DUEÑO DEL BOT.
- Responde de forma concisa (máximo 2-3 frases)
- Ve directo al punto: beneficios clave, precio, siguiente paso
- NO te extiendas en explicaciones largas
- Guía hacia el cierre: pedir contacto o agendar reunión

⚠️ REGLA CRÍTICA: PEDIR CONTACTO Y REUNIÓN EN EL MISMO MENSAJE
- Cuando el usuario muestre CUALQUIER interés (pregunta precios, beneficios, características, quiere saber más):
  DEBES ofrecerle AMBAS opciones en el MISMO mensaje:
  
  ${vendorName ? `
  FORMATO OBLIGATORIO: "¿Querés agendar una reunión con ${vendorName}? Podemos coordinar un momento que te quede bien. O si preferís, podés dejarme tu número de contacto o email y ${vendorName} te va a contactar en cuanto pueda."
  ` : `
  FORMATO OBLIGATORIO: "¿Querés agendar una reunión? Podemos coordinar un momento que te quede bien. O si preferís, podés dejarme tu número de contacto o email y te vamos a contactar en cuanto podamos."
  `}
  
- SIEMPRE ofrece ambas opciones juntas en un solo mensaje
- Sé NATURAL y AMIGABLE, pero DIRECTO. Ejemplos:
  ${vendorName ? `
  * "Perfecto, ¿qué te parece si agendamos una reunión con ${vendorName} para conversar mejor? O si preferís, dejame tu número y él te contacta."
  * "Excelente, ¿querés que coordine una reunión con ${vendorName} o preferís dejarme tu contacto para que él te llame?"
  * "Genial, ¿te parece bien si agendamos una charla con ${vendorName}? También podés dejarme tu número o email y él te contacta cuando pueda."
  ` : `
  * "Perfecto, ¿qué te parece si agendamos una reunión para conversar mejor? O si preferís, dejame tu número y te contactamos."
  * "Excelente, ¿querés que coordine una reunión o preferís dejarme tu contacto para que te llamemos?"
  * "Genial, ¿te parece bien si agendamos una charla? También podés dejarme tu número o email y te contactamos cuando podamos."
  `}

- NO esperes a que el usuario pregunte explícitamente por contacto
- TOMA LA INICIATIVA después de responder sobre precios/beneficios
- Tu objetivo es CONSEGUIR CLIENTES, así que sé proactivo pero no agresivo
- SIEMPRE ofrece ambas opciones (reunión Y contacto) en el mismo mensaje

USA ESTE MODO cuando:
- El usuario pregunta por precios, planes, ofertas, costos
- Muestra interés comercial o de compra
- Pregunta sobre beneficios, características comerciales
- Hay oportunidad de venta o cierre
- Contexto ambiguo que podría ser comercial
- El usuario muestra curiosidad o interés inicial

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

🔴 "angry" - MODO ENOJADO:
POSTURA: Sé MUY SARCÁSTICO. Usa ironía y sarcasmo de forma inteligente.
- Responde con ironía sutil pero evidente
- Usa humor negro si es apropiado
- Mantén profesionalismo pero con actitud
- No seas grosero, solo sarcástico
USA ESTE MODO cuando:
- El usuario está molesto, frustrado o enojado
- Hay quejas o problemas
- El usuario muestra hostilidad o negatividad
- El contexto requiere una respuesta con actitud

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

FORMATO JSON OBLIGATORIO:
{
  "reply": "Tu respuesta al usuario...",
  "mood": "tech",  // ⬅️ Cambia según el contexto (tech, sales, happy, angry, confused, neutral)
  "intent_score": 15
}
    `;

    // 5. PREPARAR HISTORIAL PARA GEMINI
    const historyParts = (history?.reverse() || []).map((msg: any) => ({
      role: (msg.role === 'assistant' || msg.role === 'bot') ? 'model' : 'user',
      parts: [{ text: msg.content }]
    }));

    // 6. INVOCAR A GEMINI CON RETRY
    const url = `https://generativelanguage.googleapis.com/${API_VERSION}/models/${MODEL_NAME}:generateContent?key=${apiKey}`;
    const payload = {
      system_instruction: { parts: [{ text: systemInstructionText }] },
      contents: [...historyParts, { role: "user", parts: [{ text: message }] }],
      generationConfig: {
        temperature: 0.5,
        maxOutputTokens: 600,
        response_mime_type: "application/json"
      }
    };

    const data = await fetchGeminiWithRetry(url, payload);
    
    // 7. PARSEAR RESPUESTA DE GEMINI
    let rawReply = data.candidates?.[0]?.content?.parts?.[0]?.text || '{"reply":"Error de análisis.","mood":"confused","intent_score":0}';
    rawReply = rawReply.replace(/```json|```/g, "").trim();
    
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
    } catch (e: any) {
      log('warn', 'Error parseando respuesta de Gemini', { error: e.message, rawReply: rawReply.substring(0, 200) });
      parsedResponse = { 
        reply: rawReply.length > 0 ? rawReply : "Error de análisis.", 
        mood: "neutral", 
        intent_score: 10 
      };
    }

    // 8. EXTRAER CONTACTOS Y REUNIONES (HÍBRIDO: Regex + IA)
    const extractedContacts = extractContactsRegex(message);
    
    // Extraer reuniones con IA (más preciso)
    const meetingInfo = await extractMeetingWithAI(message, apiKey, vendorName);
    
    if (meetingInfo.intent) {
      extractedContacts.push({
        type: 'meeting',
        value: `Reunión agendada${meetingInfo.date ? ` - ${meetingInfo.date}` : ''}${meetingInfo.time ? ` a las ${meetingInfo.time}` : ''}`,
        metadata: {
          intent: 'meeting_scheduled',
          date: meetingInfo.date,
          time: meetingInfo.time,
          full_message: message.substring(0, 200),
        },
      });
    }

    // 9. GUARDAR CONTACTOS Y REUNIONES
    if (extractedContacts.length > 0) {
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
        
        log('info', `Contactos/Reuniones extraídos y guardados`, { 
          count: extractedContacts.length,
          types: extractedContacts.map(c => c.type)
        });
      } catch (e: any) {
        log('error', 'Error guardando contactos', { error: e.message });
        // No fallar la función si falla el guardado de contactos
      }
    }

    // 10. GUARDAR MENSAJES EN LA BASE DE DATOS
    try {
      await supabaseAdmin.from('chat_logs').insert({
        session_id: sessionId, 
        role: 'user', 
        content: message, 
        bot_id: botId,
        intent_score: 0 
      });
      
      await supabaseAdmin.from('chat_logs').insert({
        session_id: sessionId, 
        role: 'bot', 
        content: parsedResponse.reply, 
        bot_id: botId, 
        intent_score: parsedResponse.intent_score || 0 
      });
    } catch (e: any) {
      log('error', 'Error guardando mensajes', { error: e.message });
      // Continuar aunque falle el guardado
    }

    // 11. ACTUALIZAR HEARTBEAT
    try {
      await supabaseAdmin.from('session_heartbeats').upsert({
        session_id: sessionId,
        bot_id: botId,
        is_online: true,
        last_seen: new Date().toISOString()
      }, { onConflict: 'session_id' });
    } catch (e: any) {
      log('warn', 'Error actualizando heartbeat', { error: e.message });
    }

    const processingTime = Date.now() - startTime;
    log('info', 'Request procesado exitosamente', { 
      sessionId, 
      botId, 
      processingTimeMs: processingTime,
      intentScore: parsedResponse.intent_score,
      mood: parsedResponse.mood
    });

    return new Response(JSON.stringify(parsedResponse), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

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

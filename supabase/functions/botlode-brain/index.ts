// Archivo: supabase/functions/botlode-brain/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

const MODEL_NAME = 'gemini-2.0-flash'; 
const API_VERSION = 'v1beta';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-client-session-id',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

async function fetchGeminiWithRetry(url: string, payload: any, maxRetries = 2): Promise<any> {
  for (let i = 0; i <= maxRetries; i++) {
    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      if (response.ok) return await response.json();
      if (i === maxRetries) throw new Error(`IA Error: ${response.status}`);
      await new Promise(r => setTimeout(r, 1000 * (i + 1)));
    } catch (e) {
      if (i === maxRetries) throw e;
    }
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) throw new Error('Falta GEMINI_API_KEY');

    const { sessionId, botId, message } = await req.json();
    
    if (!message) throw new Error("Mensaje vacío");
    if (!botId) throw new Error("Falta botId");

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 1. CARGAR CONFIGURACIÓN
    const { data: botConfig, error: botError } = await supabaseAdmin
      .from('bots') 
      .select('name, system_prompt') 
      .eq('id', botId)
      .single();

    if (botError || !botConfig) throw new Error("Bot no encontrado");

    // 2. OBTENER CONTEXTO
    const { data: history } = await supabaseAdmin
      .from('chat_logs')
      .select('role, content')
      .eq('session_id', sessionId)
      .order('created_at', { ascending: false })
      .limit(12); 

    // 3. INGENIERÍA DE PROMPT (MODO ANALISTA ESTRICTO)
    // ⬅️ SIMPLIFICADO: Todo en system_prompt (comportamiento, personalidad, tono, etc.)
    const systemInstructionText = `
      ROL PRINCIPAL:
      Eres "${botConfig.name}".
      ${botConfig.system_prompt || "Asiste al usuario de forma profesional."}

      ---------------------------------------------------------
      TU ROL SECUNDARIO (OCULTO): ANALISTA DE VENTAS IMPLACABLE
      Calcula el "INTENT_SCORE" (0-100) del usuario.
      
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
      POSTURA: Eres un vendedor experto de verdad. Ofrece lo que tienes de la mejor manera posible.
      - Resalta beneficios y valor
      - Presenta opciones de forma atractiva
      - Guía hacia la decisión de compra
      - Sé persuasivo pero honesto
      USA ESTE MODO cuando:
      - El usuario pregunta por precios, planes, ofertas, costos
      - Muestra interés comercial o de compra
      - Pregunta sobre beneficios, características comerciales
      - Hay oportunidad de venta o cierre
      - Contexto ambiguo que podría ser comercial
      
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

    const historyParts = (history?.reverse() || []).map((msg: any) => ({
      role: (msg.role === 'assistant' || msg.role === 'bot') ? 'model' : 'user',
      parts: [{ text: msg.content }]
    }));

    // 4. INVOCAR A GEMINI
    const url = `https://generativelanguage.googleapis.com/${API_VERSION}/models/${MODEL_NAME}:generateContent?key=${apiKey}`;
    const payload = {
      system_instruction: { parts: [{ text: systemInstructionText }] },
      contents: [...historyParts, { role: "user", parts: [{ text: message }] }],
      generationConfig: {
        temperature: 0.5, // Menor temperatura para ser más preciso con el número
        maxOutputTokens: 600,
        response_mime_type: "application/json"
      }
    };

    const data = await fetchGeminiWithRetry(url, payload);
    
    let rawReply = data.candidates?.[0]?.content?.parts?.[0]?.text || '{"reply":"Error de análisis.","mood":"confused","intent_score":0}';
    rawReply = rawReply.replace(/```json|```/g, "").trim();
    
    let parsedResponse;
    try {
        parsedResponse = JSON.parse(rawReply);
    } catch (e) {
        parsedResponse = { reply: rawReply, mood: "neutral", intent_score: 10 };
    }

    // 5. GUARDAR DATOS
    await supabaseAdmin.from('chat_logs').insert([
      { 
        session_id: sessionId, 
        role: 'user', 
        content: message, 
        bot_id: botId,
        intent_score: 0 
      },
      { 
        session_id: sessionId, 
        role: 'bot', 
        content: parsedResponse.reply, 
        bot_id: botId, 
        intent_score: parsedResponse.intent_score || 0 
      }
    ]);

    // Heartbeat
    await supabaseAdmin.from('session_heartbeats').upsert({
        session_id: sessionId,
        bot_id: botId,
        is_online: true,
        last_seen: new Date().toISOString()
    }, { onConflict: 'session_id' });

    return new Response(JSON.stringify(parsedResponse), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error: any) {
    console.error("Critical Error:", error.message);
    return new Response(JSON.stringify({ 
      reply: "Error en el sistema.", 
      mood: "confused",
      intent_score: 0
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500 
    });
  }
});
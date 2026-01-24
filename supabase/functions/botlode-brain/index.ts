// Archivo: supabase/functions/botlode-brain/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

const MODEL_NAME = 'gemini-2.0-flash'; 
const API_VERSION = 'v1beta';

// CORS: Permitimos acceso desde cualquier lado
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
  // Manejo de Preflight request (CORS)
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    // Variables de entorno
    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) throw new Error('Falta GEMINI_API_KEY');

    // DATOS ENTRANTES
    const { sessionId, botId, message } = await req.json();
    
    if (!message) throw new Error("Mensaje vacío");
    if (!botId) throw new Error("Falta botId");

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 1. CARGAR CEREBRO DEL BOT
    const { data: botConfig, error: botError } = await supabaseAdmin
      .from('bots') 
      .select('name, description, system_prompt') 
      .eq('id', botId)
      .single();

    if (botError || !botConfig) throw new Error("Bot no encontrado o desconfigurado");

    // 2. Obtener Historial de Chat (Contexto)
    const { data: history } = await supabaseAdmin
      .from('chat_logs')
      .select('role, content')
      .eq('session_id', sessionId)
      .order('created_at', { ascending: false })
      .limit(8);

    // 3. INYECTAR PERSONALIDAD + LEAD SCORING
    const systemInstructionText = `
      ERES: "${botConfig.name}".
      TU OBJETIVO PRINCIPAL: ${botConfig.description}.
      
      DIRECTIVAS ESPECÍFICAS:
      ${botConfig.system_prompt || "Actúa como un asistente útil."}

      ---------------------------------------------------------
      REGLAS DE COMPORTAMIENTO (SISTEMA CAMALEÓN):
      Debes responder SIEMPRE en formato JSON estricto.
      NO uses bloques de código markdown.

      MOODS DISPONIBLES:
      - "neutral": Conversación normal.
      - "happy": Usuario amable o buenas noticias.
      - "angry": Usuario agresivo (Defiéndete con elegancia).
      - "sales": Oportunidad de venta (Modo Vendedor).
      - "confused": Input incoherente.
      - "tech": Explicaciones técnicas.
      - "waiting": Esperando input.

      LEAD SCORING (INTENCIÓN DE COMPRA):
      Evalúa el interés del usuario del 0 al 100 en el campo "intent_score".
      - 0-30: Curiosidad general, saludos.
      - 31-70: Preguntas sobre precios, características específicas.
      - 71-100: Intención clara de compra, "quiero contratar", "¿cómo pago?".

      FORMATO DE RESPUESTA JSON OBLIGATORIO:
      { 
        "reply": "Tu respuesta en texto plano aquí", 
        "mood": "happy",
        "intent_score": 50
      }
    `;

    // Mapeo robusto: Acepta 'bot' (nuevo) y 'assistant' (viejo) como 'model' para Gemini
    const historyParts = (history?.reverse() || []).map((msg: any) => ({
      role: (msg.role === 'assistant' || msg.role === 'bot') ? 'model' : 'user',
      parts: [{ text: msg.content }]
    }));

    // 4. Llamada a Gemini
    const url = `https://generativelanguage.googleapis.com/${API_VERSION}/models/${MODEL_NAME}:generateContent?key=${apiKey}`;
    const payload = {
      system_instruction: { parts: [{ text: systemInstructionText }] },
      contents: [...historyParts, { role: "user", parts: [{ text: message }] }],
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 500,
        response_mime_type: "application/json"
      }
    };

    const data = await fetchGeminiWithRetry(url, payload);
    
    // Extracción segura
    let rawReply = data.candidates?.[0]?.content?.parts?.[0]?.text || '{"reply":"Error de conexión neuronal.","mood":"confused","intent_score":0}';
    rawReply = rawReply.replace(/```json|```/g, "").trim();
    
    let parsedResponse;
    try {
        parsedResponse = JSON.parse(rawReply);
    } catch (e) {
        parsedResponse = { reply: rawReply, mood: "neutral", intent_score: 0 };
    }

    // 5. Persistencia CORREGIDA + HEARTBEAT (Actualización de Presencia)
    
    // A) Guardamos la conversación
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

    // B) ¡NUEVO! Forzamos el estado ONLINE (Heartbeat)
    // Si la IA responde, significa que la sesión está 100% viva.
    await supabaseAdmin.from('session_heartbeats').upsert({
        session_id: sessionId,
        bot_id: botId,
        is_online: true,
        last_seen: new Date().toISOString()
    }, { onConflict: 'session_id' }); // Si ya existe, actualiza

    return new Response(JSON.stringify(parsedResponse), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error: any) {
    console.error("Critical Error:", error.message);
    return new Response(JSON.stringify({ 
      reply: "Error crítico en el núcleo. Reintentar.", 
      mood: "confused",
      intent_score: 0
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500 
    });
  }
});
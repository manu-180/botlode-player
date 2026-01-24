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
      .select('name, description, system_prompt') 
      .eq('id', botId)
      .single();

    if (botError || !botConfig) throw new Error("Bot no encontrado");

    // 2. OBTENER CONTEXTO (Historial reciente)
    const { data: history } = await supabaseAdmin
      .from('chat_logs')
      .select('role, content')
      .eq('session_id', sessionId)
      .order('created_at', { ascending: false })
      .limit(10); // Leemos un poco más para entender la evolución

    // 3. INGENIERÍA DE PROMPT (MODO ANALISTA DE VENTAS)
    const systemInstructionText = `
      ROL PRINCIPAL:
      Eres "${botConfig.name}". ${botConfig.description}.
      ${botConfig.system_prompt || "Asiste al usuario de forma profesional."}

      ---------------------------------------------------------
      TU ROL SECUNDARIO (OCULTO): ANALISTA DE VENTAS EXPERTO
      Además de responder, debes analizar psicológicamente al usuario para calcular su "INTENT_SCORE" (0-100).
      
      TABLA DE PUNTUACIÓN (SE RIGUROSO):
      - 0-20: Saludos, bromas, insultos o incoherencias. (Frio)
      - 21-40: Preguntas generales sin compromiso. (Curioso)
      - 41-70: Preguntas sobre precios, características específicas, envíos o garantías. (Considerando)
      - 71-90: Afirmaciones de interés ("Me gusta", "Lo quiero", "Suena bien"), preguntas sobre métodos de pago. (Caliente)
      - 91-100: Intención de cierre explícita ("¿Dónde firmo?", "Agendemos", doy mis datos de contacto). (Venta)

      REGLAS DE RESPUESTA JSON:
      1. "reply": Tu respuesta al usuario (Amable, persuasiva, corta).
      2. "mood": Tu estado emocional (happy, neutral, sales, tech, waiting).
      3. "intent_score": Un número entero del 0 al 100 basado en la TABLA DE PUNTUACIÓN analizando TODA la conversación.

      FORMATO JSON ESTRICTO:
      {
        "reply": "Claro, el precio es...",
        "mood": "sales",
        "intent_score": 65
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
        temperature: 0.7,
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

    // 5. GUARDAR DATOS + HEARTBEAT
    // Guardamos el mensaje del usuario
    await supabaseAdmin.from('chat_logs').insert({ 
        session_id: sessionId, 
        role: 'user', 
        content: message, 
        bot_id: botId,
        intent_score: 0 // El usuario no se puntúa a sí mismo
    });

    // Guardamos la respuesta del bot CON EL SCORE CALCULADO
    await supabaseAdmin.from('chat_logs').insert({ 
        session_id: sessionId, 
        role: 'bot', 
        content: parsedResponse.reply, 
        bot_id: botId, 
        intent_score: parsedResponse.intent_score || 0 // <--- AQUÍ SE GUARDA LA MEDICIÓN
    });

    // Actualizamos presencia
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
      reply: "Error en el sistema de procesamiento.", 
      mood: "confused",
      intent_score: 0
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500 
    });
  }
});
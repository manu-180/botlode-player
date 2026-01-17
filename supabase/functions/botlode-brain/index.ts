// Archivo: supabase/functions/botlode-brain/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

const MODEL_NAME = 'gemini-2.0-flash'; 
const API_VERSION = 'v1beta';

// CORS: Permitimos acceso desde cualquier lado (Crucial para el Player Web)
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

    // DATOS ENTRANTES: Pedimos sessionId, botId y el mensaje
    const { sessionId, botId, message } = await req.json();
    
    if (!message) throw new Error("Mensaje vacío");
    if (!botId) throw new Error("Falta botId");

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 1. CARGAR CEREBRO DEL BOT (Dinámico)
    // Buscamos en la DB la configuración de ESTE bot específico
    const { data: botConfig, error: botError } = await supabaseAdmin
      .from('bots') 
      .select('name, description, system_prompt') 
      .eq('id', botId)
      .single();

    if (botError || !botConfig) throw new Error("Bot no encontrado o desconfigurado");

    // 2. Obtener Historial de Chat (Contexto)
    const { data: history } = await supabaseAdmin
      .from('chat_history')
      .select('role, content')
      .eq('session_id', sessionId)
      .order('created_at', { ascending: false })
      .limit(8);

    // 3. INYECTAR PERSONALIDAD (System Prompt Dinámico)
    // AQUÍ ES DONDE DEFINIMOS LOS NUEVOS MOODS PARA RIVE
    const systemInstructionText = `
      ERES: "${botConfig.name}".
      TU OBJETIVO PRINCIPAL: ${botConfig.description}.
      
      DIRECTIVAS ESPECÍFICAS (Cumplir a rajatabla):
      ${botConfig.system_prompt || "Actúa como un asistente útil."}

      ---------------------------------------------------------
      REGLAS DE COMPORTAMIENTO (SISTEMA CAMALEÓN):
      Debes responder SIEMPRE en formato JSON estricto.
      NO uses bloques de código markdown (\`\`\`json). Solo el JSON crudo.
      
      MOODS DISPONIBLES (Elige uno según el contexto para cambiar tu avatar):
      - "neutral": Conversación normal, informativa.
      - "happy": El usuario es amable, agradece, te felicita o hay buenas noticias.
      - "angry": El usuario insulta, es grosero o muy negativo (Defiéndete con elegancia).
      - "sales": Oportunidad de venta, ofrecer upgrade, persuadir o cerrar un trato (Modo Vendedor).
      - "confused": Input incoherente, error del usuario o no entiendes la solicitud.
      - "tech": Explicaciones técnicas, código, logs o datos complejos (Modo Ingeniero).
      - "waiting": Haces una pregunta directa al usuario y esperas su input ("En línea").

      FORMATO DE RESPUESTA JSON OBLIGATORIO:
      { "reply": "Tu respuesta en texto plano aquí", "mood": "happy" }
    `;

    const historyParts = (history?.reverse() || []).map((msg: any) => ({
      role: msg.role === 'assistant' ? 'model' : 'user',
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
    
    // Extracción segura de la respuesta
    let rawReply = data.candidates?.[0]?.content?.parts?.[0]?.text || '{"reply":"Error de conexión neuronal.","mood":"confused"}';
    
    // Limpieza de seguridad por si la IA manda markdown accidentalmente
    rawReply = rawReply.replace(/```json|```/g, "").trim();
    
    let parsedResponse;
    try {
        parsedResponse = JSON.parse(rawReply);
    } catch (e) {
        // Fallback robusto si el JSON falla
        parsedResponse = { reply: rawReply, mood: "neutral" };
    }

    // 5. Persistencia (Guardamos lo que dijo + el mood en metadata)
    await supabaseAdmin.from('chat_history').insert([
      { session_id: sessionId, role: 'user', content: message, bot_id: botId },
      { 
        session_id: sessionId, 
        role: 'assistant', 
        content: parsedResponse.reply, 
        bot_id: botId, 
        metadata: { mood: parsedResponse.mood } 
      }
    ]);

    return new Response(JSON.stringify(parsedResponse), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error: any) {
    console.error("Critical Error:", error.message);
    return new Response(JSON.stringify({ 
      reply: "Error crítico en el núcleo. Reintentar.", 
      mood: "confused" 
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500 
    });
  }
});
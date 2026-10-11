package com.sponify.sponify

import com.ryanheise.audioservice.AudioServiceActivity

// audio_service necesita compartir el FlutterEngine con el servicio en
// segundo plano; por eso la actividad hereda de AudioServiceActivity.
class MainActivity : AudioServiceActivity()

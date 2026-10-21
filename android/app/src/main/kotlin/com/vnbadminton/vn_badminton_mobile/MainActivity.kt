package com.vnbadminton.vn_badminton_mobile

import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.CalendarContract
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// A FragmentActivity: local_auth shows the fingerprint / face prompt as a fragment.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // "Add to calendar" (lib/calendar.dart): the phone's calendar app with a new event filled in.
        // Answers false when no app can take it, and the app falls back to Google Calendar on the web.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vn_badminton/calendar").setMethodCallHandler { call, result ->
            if (call.method != "insertEvent") return@setMethodCallHandler result.notImplemented()
            val intent = Intent(Intent.ACTION_INSERT)
                .setData(CalendarContract.Events.CONTENT_URI)
                .putExtra(CalendarContract.Events.TITLE, call.argument<String>("title"))
                .putExtra(CalendarContract.Events.EVENT_LOCATION, call.argument<String>("location"))
                .putExtra(CalendarContract.Events.DESCRIPTION, call.argument<String>("description"))
                .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, call.argument<Number>("begin")!!.toLong())
                .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, call.argument<Number>("end")!!.toLong())
            try {
                startActivity(intent)
                result.success(true)
            } catch (_: ActivityNotFoundException) {
                result.success(false)
            }
        }
    }
}

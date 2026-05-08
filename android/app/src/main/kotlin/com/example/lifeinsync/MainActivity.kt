package com.example.lifeinsync

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "lifeinsync/screen_time"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"hasUsageAccess" -> result.success(hasUsageAccess())
					"getAppLabel" -> {
						val packageNameArg = call.argument<String>("packageName")
						if (packageNameArg.isNullOrBlank()) {
							result.success(null)
						} else {
							result.success(getAppLabel(packageNameArg))
						}
					}
					"getUsageEvents" -> {
						val startMs = call.argument<Number>("startMs")?.toLong()
						val endMs = call.argument<Number>("endMs")?.toLong()
						if (startMs == null || endMs == null || endMs <= startMs) {
							result.success(emptyList<Map<String, Any>>())
						} else {
							result.success(getUsageEvents(startMs, endMs))
						}
					}
					"openUsageAccessSettings" -> {
						openUsageAccessSettings()
						result.success(true)
					}
					else -> result.notImplemented()
				}
			}
	}

	private fun hasUsageAccess(): Boolean {
		val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
		val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
			appOps.unsafeCheckOpNoThrow(
				AppOpsManager.OPSTR_GET_USAGE_STATS,
				Process.myUid(),
				packageName
			)
		} else {
			@Suppress("DEPRECATION")
			appOps.checkOpNoThrow(
				AppOpsManager.OPSTR_GET_USAGE_STATS,
				Process.myUid(),
				packageName
			)
		}
		return mode == AppOpsManager.MODE_ALLOWED
	}

	private fun openUsageAccessSettings() {
		val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
		intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
		startActivity(intent)
	}

	private fun getAppLabel(packageName: String): String? {
		return try {
			val pm = packageManager
			val appInfo = pm.getApplicationInfo(packageName, 0)
			pm.getApplicationLabel(appInfo).toString()
		} catch (_: Exception) {
			null
		}
	}

	private fun getUsageEvents(startMs: Long, endMs: Long): List<Map<String, Any>> {
		val usageStatsManager =
			getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
		val usageEvents = usageStatsManager.queryEvents(startMs, endMs)
		val event = UsageEvents.Event()
		val results = mutableListOf<Map<String, Any>>()

		while (usageEvents.hasNextEvent()) {
			usageEvents.getNextEvent(event)
			val pkg = event.packageName ?: continue
			val type = event.eventType
			results.add(
				mapOf(
					"packageName" to pkg,
					"timestamp" to event.timeStamp,
					"eventType" to type
				)
			)
		}

		return results
	}
}

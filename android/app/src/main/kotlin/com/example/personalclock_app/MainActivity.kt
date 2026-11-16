package com.example.personalclock_app

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.ContentObserver
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfDocument
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity: FlutterActivity() {
    private val ALARM_CHANNEL = "alarm_channel"
    private val SOUND_CHANNEL = "alarm_sound_channel"
    private val TIMER_CHANNEL = "timer_channel"
    private val QR_PRINT_CHANNEL = "qr_print_channel"
    private val RINGTONE_CHANNEL = "ringtone_channel"
    private val PERMISSION_CHANNEL = "permission_channel"
    
    private var mediaPlayer: MediaPlayer? = null
    private var audioManager: AudioManager? = null
    private var previousVolume: Int = 0
    private val PICK_RINGTONE_REQUEST = 1001
    
    private var volumeObserver: ContentObserver? = null
    private val volumeHandler = Handler(Looper.getMainLooper())
    private var isAlarmRinging = false

    companion object {
        const val NOTIFICATION_CHANNEL_ID = "timer_channel"
        const val ALARM_NOTIFICATION_CHANNEL_ID = "alarm_channel_notification"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                android.view.WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }

        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        createNotificationChannel()

        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            // Alarm scheduling channel
            MethodChannel(messenger, ALARM_CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleAlarm" -> {
                        val alarmId = call.argument<Int>("alarmId") ?: 0
                        val triggerTime = call.argument<Long>("triggerTime") ?: 0L
                        val title = call.argument<String>("title") ?: "Alarm"
                        val customRingtone = call.argument<String?>("customRingtone")
                        scheduleAlarm(alarmId, triggerTime, title, customRingtone)
                        result.success(null)
                    }
                    "cancelAlarm" -> {
                        val alarmId = call.argument<Int>("alarmId") ?: 0
                        cancelAlarm(alarmId)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

            // Sound playback channel
            MethodChannel(messenger, SOUND_CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "playAlarmSound" -> {
                        val customRingtone = call.argument<String?>("customRingtone")
                        playAlarmSound(customRingtone)
                        result.success(null)
                    }
                    "stopAlarmSound" -> {
                        stopAlarmSound()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

            // Timer notification channel
            MethodChannel(messenger, TIMER_CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "showTimerNotification" -> {
                        val title = call.argument<String>("title") ?: "Timer"
                        val message = call.argument<String>("message") ?: "Complete"
                        showTimerNotification(title, message)
                        result.success(null)
                    }
                    "playNotificationSound" -> {
                        playNotificationSound()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

            // QR Print/Share channel
            MethodChannel(messenger, QR_PRINT_CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareQRCode" -> {
                        val qrData = call.argument<String>("qrData") ?: ""
                        shareQRCode(qrData)
                        result.success(null)
                    }
                    "printQRCode" -> {
                        val qrData = call.argument<String>("qrData") ?: ""
                        printQRCode(qrData)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

            // Ringtone picker channel
            MethodChannel(messenger, RINGTONE_CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickRingtone" -> {
                        pickRingtone()
                        result.success(null)
                    }
                    "getDefaultRingtones" -> {
                        val ringtones = getDefaultRingtones()
                        result.success(ringtones)
                    }
                    else -> result.notImplemented()
                }
            }

            // Permission channel
            MethodChannel(messenger, PERMISSION_CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestNotificationPermission" -> {
                        requestNotificationPermission()
                        result.success(null)
                    }
                    "requestExactAlarmPermission" -> {
                        requestExactAlarmPermission()
                        result.success(null)
                    }
                    "requestOverlayPermission" -> {
                        requestOverlayPermission()
                        result.success(null)
                    }
                    "requestCameraPermission" -> {
                        requestCameraPermission()
                        result.success(null)
                    }
                    // ✅ NEW: Get app install time to detect reinstalls
                    "getInstallTime" -> {
                        val installTime = getAppInstallTime()
                        result.success(installTime)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        handleAlarmIntent(intent)
    }

    // ✅ NEW: Get app install time to detect reinstalls
    private fun getAppInstallTime(): Long {
        return try {
            val packageInfo = packageManager.getPackageInfo(packageName, 0)
            packageInfo.firstInstallTime
        } catch (e: Exception) {
            e.printStackTrace()
            0L
        }
    }

    // Permission Methods
    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this, 
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    100
                )
            }
        }
    }

    private fun requestExactAlarmPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            if (!alarmManager.canScheduleExactAlarms()) {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                        data = Uri.parse("package:$packageName")
                    }
                    startActivity(intent)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    private fun requestCameraPermission() {
        if (ContextCompat.checkSelfPermission(
                this, 
                Manifest.permission.CAMERA
            ) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.CAMERA),
                101
            )
        }
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                try {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName")
                    )
                    startActivity(intent)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val timerChannel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Timer Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for timer completion"
                enableLights(true)
                lightColor = Color.BLUE
                enableVibration(true)
            }

            val alarmChannel = NotificationChannel(
                ALARM_NOTIFICATION_CHANNEL_ID,
                "Alarm Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alarm notifications and ringtones"
                enableLights(true)
                lightColor = Color.RED
                enableVibration(true)
                setSound(null, null)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(timerChannel)
            notificationManager.createNotificationChannel(alarmChannel)
        }
    }

    private fun showTimerNotification(title: String, message: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .build()

        notificationManager.notify(1001, notification)
    }

    private fun playNotificationSound() {
        try {
            val notification = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val ringtone = RingtoneManager.getRingtone(applicationContext, notification)
            ringtone.play()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun printQRCode(qrData: String) {
        try {
            val printManager = getSystemService(Context.PRINT_SERVICE) as PrintManager
            val jobName = "Alarm QR Code"
            
            val printAdapter = object : PrintDocumentAdapter() {
                override fun onLayout(
                    oldAttributes: PrintAttributes?,
                    newAttributes: PrintAttributes?,
                    cancellationSignal: android.os.CancellationSignal?,
                    callback: LayoutResultCallback?,
                    extras: Bundle?
                ) {
                    if (cancellationSignal?.isCanceled == true) {
                        callback?.onLayoutCancelled()
                        return
                    }

                    val info = PdfDocument.PageInfo.Builder(595, 842, 1).create()
                    callback?.onLayoutFinished(
                        android.print.PrintDocumentInfo.Builder(jobName)
                            .setContentType(android.print.PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                            .setPageCount(1)
                            .build(),
                        true
                    )
                }

                override fun onWrite(
                    pages: Array<out android.print.PageRange>?,
                    destination: android.os.ParcelFileDescriptor?,
                    cancellationSignal: android.os.CancellationSignal?,
                    callback: WriteResultCallback?
                ) {
                    try {
                        val pdfDocument = PdfDocument()
                        val pageInfo = PdfDocument.PageInfo.Builder(595, 842, 1).create()
                        val page = pdfDocument.startPage(pageInfo)
                        val canvas = page.canvas

                        // Generate QR code
                        val size = 400
                        val qrCodeWriter = QRCodeWriter()
                        val bitMatrix = qrCodeWriter.encode(qrData, BarcodeFormat.QR_CODE, size, size)
                        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.RGB_565)
                        
                        for (x in 0 until size) {
                            for (y in 0 until size) {
                                bitmap.setPixel(x, y, if (bitMatrix[x, y]) Color.BLACK else Color.WHITE)
                            }
                        }

                        // Draw QR code centered
                        val left = (pageInfo.pageWidth - size) / 2f
                        val top = (pageInfo.pageHeight - size) / 2f
                        canvas.drawBitmap(bitmap, left, top, null)

                        // Draw title
                        val paint = android.graphics.Paint()
                        paint.textSize = 24f
                        paint.textAlign = android.graphics.Paint.Align.CENTER
                        canvas.drawText(
                            "Alarm QR Code",
                            pageInfo.pageWidth / 2f,
                            top - 40f,
                            paint
                        )

                        // Draw instructions
                        paint.textSize = 16f
                        canvas.drawText(
                            "Scan this code to dismiss your QR alarms",
                            pageInfo.pageWidth / 2f,
                            top + size + 40f,
                            paint
                        )

                        pdfDocument.finishPage(page)
                        
                        destination?.let {
                            val outputStream = FileOutputStream(it.fileDescriptor)
                            pdfDocument.writeTo(outputStream)
                            outputStream.close()
                        }
                        
                        pdfDocument.close()

                        callback?.onWriteFinished(arrayOf(android.print.PageRange.ALL_PAGES))
                    } catch (e: Exception) {
                        callback?.onWriteFailed(e.message)
                    }
                }
            }

            printManager.print(jobName, printAdapter, null)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun shareQRCode(qrData: String) {
        try {
            val size = 512
            val qrCodeWriter = QRCodeWriter()
            val bitMatrix = qrCodeWriter.encode(qrData, BarcodeFormat.QR_CODE, size, size)
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.RGB_565)
            
            for (x in 0 until size) {
                for (y in 0 until size) {
                    bitmap.setPixel(x, y, if (bitMatrix[x, y]) Color.BLACK else Color.WHITE)
                }
            }

            val cachePath = File(cacheDir, "images")
            cachePath.mkdirs()
            val file = File(cachePath, "qr_code.png")
            val stream = FileOutputStream(file)
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.close()

            val contentUri = FileProvider.getUriForFile(this, "${packageName}.fileprovider", file)
            
            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, contentUri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            startActivity(Intent.createChooser(shareIntent, "Share QR Code"))
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun pickRingtone() {
        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Select Alarm Sound")
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
        }
        startActivityForResult(intent, PICK_RINGTONE_REQUEST)
    }

    private fun getDefaultRingtones(): List<Map<String, String>> {
        val ringtones = mutableListOf<Map<String, String>>()
        
        ringtones.add(mapOf(
            "name" to "Default Alarm",
            "uri" to "default"
        ))

        val manager = RingtoneManager(this)
        manager.setType(RingtoneManager.TYPE_ALARM)
        val cursor = manager.cursor

        while (cursor.moveToNext()) {
            val title = cursor.getString(RingtoneManager.TITLE_COLUMN_INDEX)
            val uri = manager.getRingtoneUri(cursor.position).toString()
            ringtones.add(mapOf("name" to title, "uri" to uri))
        }

        return ringtones
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == PICK_RINGTONE_REQUEST && resultCode == RESULT_OK) {
            val uri = data?.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
            
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, RINGTONE_CHANNEL).invokeMethod(
                    "ringtoneSelected",
                    uri?.toString()
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleAlarmIntent(intent)
    }

    private fun handleAlarmIntent(intent: Intent?) {
        if (intent?.action == "ALARM_TRIGGER") {
            val alarmId = intent.getIntExtra("alarmId", 0)
            val customRingtone = intent.getStringExtra("customRingtone")
            
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, ALARM_CHANNEL).invokeMethod(
                    "triggerAlarm",
                    mapOf("alarmId" to alarmId, "customRingtone" to customRingtone)
                )
            }
        }
    }

    private fun scheduleAlarm(alarmId: Int, triggerTimeMillis: Long, title: String, customRingtone: String?) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            action = "ALARM_TRIGGER"
            putExtra("alarmId", alarmId)
            putExtra("title", title)
            putExtra("customRingtone", customRingtone)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            this,
            alarmId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerTimeMillis,
                pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                triggerTimeMillis,
                pendingIntent
            )
        }
    }

    private fun cancelAlarm(alarmId: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            alarmId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
    }

    private fun startVolumeMonitoring() {
        volumeObserver = object : ContentObserver(volumeHandler) {
            override fun onChange(selfChange: Boolean) {
                if (isAlarmRinging) {
                    audioManager?.let { am ->
                        val currentVolume = am.getStreamVolume(AudioManager.STREAM_ALARM)
                        val maxVolume = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                        
                        if (currentVolume < maxVolume) {
                            am.setStreamVolume(AudioManager.STREAM_ALARM, maxVolume, 0)
                        }
                    }
                }
            }
        }
        
        contentResolver.registerContentObserver(
            Settings.System.CONTENT_URI,
            true,
            volumeObserver!!
        )
    }

    private fun stopVolumeMonitoring() {
        volumeObserver?.let {
            contentResolver.unregisterContentObserver(it)
            volumeObserver = null
        }
    }

    private fun playAlarmSound(customRingtone: String?) {
        try {
            stopAlarmSound()
            
            isAlarmRinging = true

            audioManager?.let { am ->
                previousVolume = am.getStreamVolume(AudioManager.STREAM_ALARM)
                val maxVolume = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                am.setStreamVolume(AudioManager.STREAM_ALARM, maxVolume, 0)
            }
            
            startVolumeMonitoring()

            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .build()
                )
                
                if (customRingtone != null && customRingtone != "default") {
                    setDataSource(this@MainActivity, Uri.parse(customRingtone))
                } else {
                    val afd = context.resources.openRawResourceFd(R.raw.alarm_sound)
                    setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    afd.close()
                }
                
                isLooping = true
                setVolume(1.0f, 1.0f)
                prepare()
                start()
            }
            
            volumeHandler.post(object : Runnable {
                override fun run() {
                    if (isAlarmRinging && mediaPlayer?.isPlaying == true) {
                        audioManager?.let { am ->
                            val maxVolume = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                            am.setStreamVolume(AudioManager.STREAM_ALARM, maxVolume, 0)
                        }
                        volumeHandler.postDelayed(this, 500)
                    }
                }
            })
            
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopAlarmSound() {
        isAlarmRinging = false
        stopVolumeMonitoring()
        volumeHandler.removeCallbacksAndMessages(null)
        
        mediaPlayer?.apply {
            if (isPlaying) {
                stop()
            }
            release()
        }
        mediaPlayer = null

        audioManager?.setStreamVolume(AudioManager.STREAM_ALARM, previousVolume, 0)
    }

    override fun onDestroy() {
        stopAlarmSound()
        super.onDestroy()
    }
}

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "ALARM_TRIGGER") {
            val alarmId = intent.getIntExtra("alarmId", 0)
            val title = intent.getStringExtra("title") ?: "Alarm"
            val customRingtone = intent.getStringExtra("customRingtone")

            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK or 
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "ClockApp::AlarmWakeLock"
            )
            wakeLock.acquire(10 * 60 * 1000L)

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                action = "ALARM_TRIGGER"
                putExtra("alarmId", alarmId)
                putExtra("title", title)
                putExtra("customRingtone", customRingtone)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            
            context.startActivity(launchIntent)

            Handler(Looper.getMainLooper()).postDelayed({
                if (wakeLock.isHeld) {
                    wakeLock.release()
                }
            }, 5000)
        }
    }
}
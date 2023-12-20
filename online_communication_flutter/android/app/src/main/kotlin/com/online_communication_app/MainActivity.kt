package com.online_communication_app

import android.app.Activity
import android.media.projection.MediaProjectionManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Bundle
import android.os.PersistableBundle


class MainActivity: FlutterActivity() {

    private val CAPTURE_PERMISSION_REQUEST_CODE = 1
    private var mediaProjectionPermission: Boolean = false;

    override fun onCreate(savedInstanceState: Bundle?, persistentState: PersistableBundle?) {
		super.onCreate(savedInstanceState, persistentState)
		if (DEBUG) Log.v(TAG, "onCreate:");
	}
    
    override fun onDestroy() {
		if (DEBUG) Log.v(TAG, "onDestroy:");
		super.onDestroy()
	}

     // 画面キャプチャactivity
     override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent ?) {
        if (requestCode != CAPTURE_PERMISSION_REQUEST_CODE) return

        if (resultCode == Activity.RESULT_OK && data != null) {
            mediaProjectionPermission = true;
        }
        else{
            mediaProjectionPermission = false;
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		if (DEBUG) Log.v(TAG, "configureFlutterEngine:");
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Const.METHOD_CHANNEL_NAME)
			.setMethodCallHandler { call, result -> onMethodCall(call, result) }
	}

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
		when (call.method) {
        "startForegroundService" -> {
            startForegroundService(call, result)
        }
        "startCaptureStream" -> {
            startCaptureStream(call, result)
        }
        "stopCaptureStream" -> {
			stopCaptureStream(call, result);
		}
		else -> {
			Log.w(TAG, "unknown method call${call}")
		}
		}
		// FIXME Dart側からのsetter/getter呼び出しを実装する
    }

     /**
     * ForegroundServiceを開始
     * @param call
     * @param result
     */
    private fun startForegroundService(call: MethodCall, result: MethodChannel.Result) {
        if (DEBUG) Log.v(TAG, "startForegroundService:${call}")
        requestMediaProjectionPermission(result)
        result.success("success")
    }

     /**
     * 画面共有許可を修得
     * @param call
     * @param result
     */
    private fun requestMediaProjectionPermission(result: MethodChannel.Result) {
        ForegroundService.startService(this, "Foreground Service is running...")
        val mediaProjectionManager =
            getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(
            mediaProjectionManager.createScreenCaptureIntent(),
            CAPTURE_PERMISSION_REQUEST_CODE
        )
    }

      /**
     * 画面共有を開始
     * @param call
     * @param result
     */
    private fun startCaptureStream(call: MethodCall, result: MethodChannel.Result) {

        if (DEBUG) Log.v(TAG, "startCaptureStream:${call}")
        if(mediaProjectionPermission){
            result.success(true)
        }
        else{
            // 画面キャプチ許可ない場合false
            result.success(mediaProjectionPermission)
            // end foreground service
            ForegroundService.stopService(this)
        }
        
    }


    /**
     * 画面共有を完了
     * @param call
     * @param result
     */
    private fun stopCaptureStream(call: MethodCall, result: MethodChannel.Result) {
        if (DEBUG) Log.v(TAG, "startLocalStream:${call}")
        // end foreground service
        ForegroundService.stopService(this)
        mediaProjectionPermission = false
        result.success("success")
    }

    companion object {
        private const val DEBUG = false // set false on production
        private val TAG = MainActivity::class.java.simpleName
    }

}

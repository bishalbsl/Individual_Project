package com.online_communication_app

internal object Const {
	/**
	 * MainActivityで実装するメソッドチャネル名
	 */
	const val METHOD_CHANNEL_NAME = "com.oec.onlineCommunication/method"

	/**
	 * MainActivityで実装するメソッドチャネル名
	 */
	const val EVENT_CHANNEL_NAME = "com.oec.onlineCommunication/event"


	enum class CaptureEvent {
		/**
		 * SFUまたはMeshルームをオープンした(自分が入室した)
		 */
		OnOpenRoom,
	}
}
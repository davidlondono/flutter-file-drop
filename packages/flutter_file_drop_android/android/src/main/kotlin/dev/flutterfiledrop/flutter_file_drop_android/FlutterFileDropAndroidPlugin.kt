package dev.flutterfiledrop.flutter_file_drop_android

import android.app.Activity
import android.content.ClipData
import android.content.Context
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.view.DragEvent
import android.view.DragAndDropPermissions
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler
import java.io.InputStream
import java.util.UUID

class FlutterFileDropAndroidPlugin :
    FlutterPlugin,
    ActivityAware,
    DropFileHostApi,
    StreamHandler {
    private lateinit var applicationContext: Context
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventSink? = null
    private var activity: Activity? = null
    private var flutterView: FlutterView? = null
    private var currentSessionId: String? = null
    private val files = mutableMapOf<String, MutableMap<String, Uri>>()
    private val dragPermissions = mutableMapOf<String, DragAndDropPermissions>()

    private val dragListener = View.OnDragListener { view, event -> handleDrag(view, event) }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        eventChannel = EventChannel(binding.binaryMessenger, "flutter_file_drop/events")
        eventChannel.setStreamHandler(this)
        DropFileHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        releaseAllSessions()
        eventChannel.setStreamHandler(null)
        DropFileHostApi.setUp(binding.binaryMessenger, null)
        detachView()
    }

    override fun onListen(arguments: Any?, events: EventSink) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attachActivity(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() = detachView()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        attachActivity(binding.activity)
    }

    override fun onDetachedFromActivity() = detachView()

    private fun attachActivity(newActivity: Activity) {
        detachView()
        activity = newActivity
        val view = findFlutterView(newActivity.window.decorView)
        flutterView = view
        view?.setOnDragListener(dragListener)
    }

    private fun detachView() {
        flutterView?.setOnDragListener(null)
        flutterView = null
        activity = null
        currentSessionId = null
    }

    private fun findFlutterView(root: View): FlutterView? {
        if (root is FlutterView) return root
        if (root !is ViewGroup) return null
        for (index in 0 until root.childCount) {
            findFlutterView(root.getChildAt(index))?.let { return it }
        }
        return null
    }

    private fun handleDrag(view: View, event: DragEvent): Boolean {
        when (event.action) {
            DragEvent.ACTION_DRAG_STARTED -> return event.clipDescription != null && eventSink != null
            DragEvent.ACTION_DRAG_ENTERED -> {
                currentSessionId = "android-" + UUID.randomUUID().toString()
                emit("enter", view, event, event.clipData, dropped = false)
                return true
            }
            DragEvent.ACTION_DRAG_LOCATION -> {
                if (currentSessionId == null) currentSessionId = "android-" + UUID.randomUUID().toString()
                emit("move", view, event, event.clipData, dropped = false)
                return true
            }
            DragEvent.ACTION_DRAG_EXITED -> {
                emit("leave", view, event, event.clipData, dropped = false)
                currentSessionId = null
                return true
            }
            DragEvent.ACTION_DROP -> {
                val sessionId = currentSessionId ?: "android-" + UUID.randomUUID().toString()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    activity?.requestDragAndDropPermissions(event)?.let {
                        dragPermissions[sessionId] = it
                    }
                }
                emit("drop", view, event, event.clipData, dropped = true, sessionId = sessionId)
                return true
            }
            DragEvent.ACTION_DRAG_ENDED -> {
                currentSessionId = null
                return true
            }
        }
        return false
    }

    private fun emit(
        type: String,
        view: View,
        event: DragEvent,
        clipData: ClipData?,
        dropped: Boolean,
        sessionId: String = currentSessionId ?: "android-" + UUID.randomUUID().toString(),
    ) {
        val density = view.resources.displayMetrics.density
        eventSink?.success(
            mapOf(
                "sessionId" to sessionId,
                "type" to type,
                "globalX" to event.x / density,
                "globalY" to event.y / density,
                "items" to makeItems(clipData, sessionId, dropped),
            ),
        )
        if (type == "drop") currentSessionId = null
    }

    private fun makeItems(clipData: ClipData?, sessionId: String, dropped: Boolean): List<Map<String, Any?>> {
        if (clipData == null) return emptyList()
        return (0 until clipData.itemCount).mapNotNull { index ->
            val item = clipData.getItemAt(index)
            val uri = item.uri
            if (uri != null) {
                if (uri.scheme == "http" || uri.scheme == "https") {
                    return@mapNotNull mapOf(
                        "type" to "string",
                        "mimeType" to "text/uri-list",
                        "value" to if (dropped) uri.toString() else null,
                    )
                }
                return@mapNotNull fileItem(uri, index, sessionId, dropped)
            }
            val html = item.htmlText
            if (html != null) {
                return@mapNotNull mapOf(
                    "type" to "string",
                    "mimeType" to "text/html",
                    "value" to if (dropped) html else null,
                )
            }
            val text = item.text
            if (text != null) {
                return@mapNotNull mapOf(
                    "type" to "string",
                    "mimeType" to "text/plain",
                    "value" to if (dropped) text.toString() else null,
                )
            }
            null
        }
    }

    private fun fileItem(uri: Uri, index: Int, sessionId: String, dropped: Boolean): Map<String, Any?> {
        val resolver = applicationContext.contentResolver
        var name: String? = uri.lastPathSegment
        var size: Long? = null
        var lastModified: Long? = null
        try {
            resolver.query(
                uri,
                arrayOf(
                    OpenableColumns.DISPLAY_NAME,
                    OpenableColumns.SIZE,
                    DocumentsContract.Document.COLUMN_LAST_MODIFIED,
                ),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameColumn = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameColumn >= 0) name = cursor.getString(nameColumn) ?: name
                    val sizeColumn = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (sizeColumn >= 0 && !cursor.isNull(sizeColumn)) size = cursor.getLong(sizeColumn)
                    val modifiedColumn = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
                    if (modifiedColumn >= 0 && !cursor.isNull(modifiedColumn)) lastModified = cursor.getLong(modifiedColumn)
                }
            }
        } catch (_: Exception) {
            // Metadata is best-effort. Access failure is checked separately below.
        }
        val mimeType = try { resolver.getType(uri) } catch (_: Exception) { null }
        val isDirectory = mimeType == DocumentsContract.Document.MIME_TYPE_DIR ||
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && DocumentsContract.isTreeUri(uri))
        var accessDenied = false
        if (dropped && !isDirectory) {
            try {
                resolver.openFileDescriptor(uri, "r")?.use { }
                    ?: run { accessDenied = true }
            } catch (_: Exception) {
                accessDenied = true
            }
            if (!accessDenied) files.getOrPut(sessionId) { mutableMapOf() }[index.toString()] = uri
        }
        return mapOf(
            "type" to "file",
            "handle" to if (dropped && !accessDenied) index.toString() else null,
            "name" to name,
            "mimeType" to mimeType,
            "size" to size,
            "lastModifiedMilliseconds" to lastModified,
            "path" to if (uri.scheme.equals("file", ignoreCase = true)) uri.path else null,
            "accessDenied" to accessDenied,
            "isDirectory" to isDirectory,
        )
    }

    override suspend fun readFileChunk(sessionId: String, fileHandle: String, offset: Long, maxBytes: Long): ByteArray? {
        if (offset < 0 || maxBytes <= 0 || maxBytes > 64 * 1024) return null
        val uri = files[sessionId]?.get(fileHandle) ?: return null
        val input = applicationContext.contentResolver.openInputStream(uri) ?: return null
        input.use { stream ->
            skipExactly(stream, offset)
            val buffer = ByteArray(maxBytes.toInt())
            val count = stream.read(buffer)
            if (count <= 0) return null
            return if (count == buffer.size) buffer else buffer.copyOf(count)
        }
    }

    override suspend fun releaseSession(sessionId: String) {
        files.remove(sessionId)
        dragPermissions.remove(sessionId)?.release()
    }

    private fun releaseAllSessions() {
        files.clear()
        dragPermissions.values.forEach(DragAndDropPermissions::release)
        dragPermissions.clear()
    }

    private fun skipExactly(input: InputStream, count: Long) {
        var remaining = count
        while (remaining > 0) {
            val skipped = input.skip(remaining)
            if (skipped > 0) {
                remaining -= skipped
            } else if (input.read() == -1) {
                return
            } else {
                remaining--
            }
        }
    }
}

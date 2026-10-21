package dev.flutterfiledrop.flutter_file_drop_android

import java.io.ByteArrayInputStream
import java.io.FilterInputStream
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class SequentialFileReadTest {
    @Test
    fun readsChunksInOrderWithoutRescanningEarlierBytes() {
        val stream = CountingInputStream(byteArrayOf(1, 2, 3, 4, 5, 6))
        val read = SequentialFileRead(stream)

        assertContentEquals(byteArrayOf(1, 2, 3), read.read(0, 3))
        assertContentEquals(byteArrayOf(4, 5, 6), read.read(3, 3))
        assertNull(read.read(6, 3))
        assertEquals(6, stream.bytesRead)

        read.close()
        assertTrue(stream.closed)
    }
}

private class CountingInputStream(bytes: ByteArray) : FilterInputStream(ByteArrayInputStream(bytes)) {
    var bytesRead = 0
    var closed = false

    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
        val count = super.read(buffer, offset, length)
        if (count > 0) bytesRead += count
        return count
    }

    override fun close() {
        closed = true
        super.close()
    }
}

package trip

import kotlin.test.Test
import kotlin.test.assertEquals

class ClampTest {
    @Test
    fun below() {
        assertEquals(0, clamp(-1, 0, 10))
    }

    @Test
    fun inside() {
        assertEquals(5, clamp(5, 0, 10))
    }
}

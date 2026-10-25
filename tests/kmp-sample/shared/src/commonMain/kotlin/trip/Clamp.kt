package trip

fun clamp(v: Int, lo: Int, hi: Int): Int {
    if (v < lo) {
        return lo
    }
    if (v > hi) {
        return hi
    }
    return v
}

package trip

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.sp

@Composable
fun App() {
    Column(
        modifier = Modifier.fillMaxSize().background(Color(0xFF1565C0)),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        val style = TextStyle(color = Color.White, fontSize = 32.sp)
        BasicText(text = "Sample", style = style)
        BasicText(text = clamp(15, 0, 10).toString(), style = style)
    }
}

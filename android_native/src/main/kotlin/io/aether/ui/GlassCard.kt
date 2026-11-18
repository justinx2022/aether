package io.aether.ui

import android.os.Build
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Hardware-accelerated frosted glass card for Android Jetpack Compose.
 *
 * Utilizes native RenderEffect blur on Android 12+ (API 31+) and an authentic
 * specular rim gradient reflecting the iOS 27 design language.
 */
@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 18.dp,
    specularAlpha: Float = 0.65f,
    content: @Composable BoxScope.() -> Unit
) {
    val shape = RoundedCornerShape(cornerRadius)

    val specularBrush = Brush.linearGradient(
        colors = listOf(
            Color.White.copy(alpha = specularAlpha),
            Color.White.copy(alpha = specularAlpha * 0.25f),
            Color.Transparent,
            Color.White.copy(alpha = specularAlpha * 0.15f)
        )
    )

    Box(
        modifier = modifier
            .shadow(elevation = 10.dp, shape = shape, spotColor = Color.Black.copy(alpha = 0.25f))
            .clip(shape)
            .then(
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    Modifier.blur(20.dp)
                } else {
                    Modifier
                }
            )
            .background(Color(0xFF1E1E24).copy(alpha = 0.65f))
            .border(width = 1.2.dp, brush = specularBrush, shape = shape),
        content = content
    )
}

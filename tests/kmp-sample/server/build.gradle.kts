plugins {
    alias(libs.plugins.kotlin.jvm)
    application
}

application {
    mainClass = "trip.ServerKt"
}

dependencies {
    implementation(libs.ktor.server.core)
    implementation(libs.ktor.server.netty)
    testImplementation(libs.ktor.server.test.host)
    testImplementation(libs.kotlin.test)
}

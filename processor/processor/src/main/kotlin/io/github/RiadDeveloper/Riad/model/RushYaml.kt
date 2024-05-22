package io.github.shreyashsaitwal.Riad.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class RiadYaml(
    val version: String,
    val license: String = "",
    val homepage: String = "",
    val desugar: Boolean = false,
    @SerialName("min_sdk") val minSdk: Int = 7,

    val assets: List<String> = listOf(),
    val authors: List<String> = listOf(),
    val repositories: List<String> = listOf(),

    val kotlin: Kotlin = Kotlin(),

    @SerialName("dependencies") val runtimeDeps: List<String> = listOf(),
    @SerialName("provided_dependencies") val providedDeps: List<String> = listOf(),
)

@Serializable
data class Kotlin(
    @SerialName("compiler_version") val compilerVersion: String? = null,
)

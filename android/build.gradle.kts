// --- PLUGINS ---
plugins {
    id("com.android.application") apply false
    id("com.android.library") apply false
    id("org.jetbrains.kotlin.android") apply false
}

// --- REPOSITORIES ---
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// --- CUSTOM BUILD DIRECTORIES ---
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// --- EVALUATION ORDER ---
subprojects {
    project.evaluationDependsOn(":app")
}

// --- CLEAN TASK ---
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// --- BUILDSCRIPT (KOTLIN + GRADLE PLUGIN) ---
buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        // Flutter ve pdf_render ile uyumlu Kotlin sürümü
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.10")
        classpath("com.android.tools.build:gradle:8.2.1")
    }
}

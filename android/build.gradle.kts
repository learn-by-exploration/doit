allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Plugin subprojects (file_picker, etc.) ship their own
// build.gradle and pin to an older compileSdk. file_picker
// transitively pulls in flutter_plugin_android_lifecycle,
// whose AAR metadata now requires compileSdk 36+. Force every
// Android subproject to compile against 36 so the
// `checkDebugAarMetadata` task passes. minSdk and targetSdk
// in the app module are unchanged (28 / flutter default).
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            extensions.configure<com.android.build.gradle.BaseExtension>("android") {
                compileSdkVersion(36)
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

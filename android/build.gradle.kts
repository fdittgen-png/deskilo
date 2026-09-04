allprojects {
    repositories {
        google()
        mavenCentral()
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

// #835 — REPRODUCIBLE NATIVE LIBRARIES.
//
// F-Droid rebuilds the pinned commit and compares it to the APK we
// publish. Everything matched except two files:
//
//     lib/<abi>/libdartjni.so
//     lib/<abi>/libflutter_zxing.so
//
// Both are CMake/NDK output from plugins. libapp.so (Dart AOT) matched,
// so the build-path relocation is doing its job; what is left is native
// linking, and two things in it are not deterministic across machines.
//
//  1. THE BUILD ID. The linker writes a .note.gnu.build-id hash by
//     default. Nothing reads it here, and it is the classic reason two
//     otherwise identical .so files differ. --build-id=none removes it.
//
//  2. THE NDK VERSION. A plugin that does not pin one gets whatever the
//     machine offers, and a different clang is a different binary.
//     F-Droid's builder installed two NDKs for this project, which is
//     the shape of exactly that. Every module is pinned to the app's,
//     which both sides take from the same pinned Flutter.
//
// This lives in the SOURCE, not in the F-Droid recipe's prebuild, so our
// published APK and their rebuild get it from one place. A fix only one
// side applies is not a fix.
subprojects {
    afterEvaluate {
        val androidExtension = extensions.findByName("android")
        if (androidExtension is com.android.build.gradle.BaseExtension) {
            val appNdk = project(":app").extensions
                .findByName("android")
                .let { it as? com.android.build.gradle.BaseExtension }
                ?.ndkVersion
            if (appNdk != null) {
                androidExtension.ndkVersion = appNdk
            }
            androidExtension.defaultConfig.externalNativeBuild.cmake.arguments(
                "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,--build-id=none",
                "-DCMAKE_MODULE_LINKER_FLAGS=-Wl,--build-id=none",
                "-DCMAKE_EXE_LINKER_FLAGS=-Wl,--build-id=none",
            )
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

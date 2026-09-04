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
// publish. Their log named exactly what differed, and it was two files:
//
//     lib/<abi>/libdartjni.so
//     lib/<abi>/libflutter_zxing.so
//
// Both are CMake/NDK output from plugins. libapp.so — the Dart AOT blob
// the build-path relocation exists for — MATCHED, as did libflutter.so
// and every resource, dex and manifest entry. So the relocation works,
// and what is left is native linking.
//
// The linker writes a .note.gnu.build-id hash into every shared object
// by default. Nothing reads it here, and it is the classic reason two
// otherwise identical .so files differ. --build-id=none removes it.
//
// This lives in the SOURCE, not in the F-Droid recipe's prebuild, so our
// published APK and their rebuild get it from one place. A determinism
// fix only one side applies is not a fix.
//
// Configured through plugins.withId rather than afterEvaluate: the
// evaluationDependsOn(":app") above has already evaluated projects by
// the time this block runs, and afterEvaluate on an evaluated project is
// an error ("Cannot run Project.afterEvaluate when the project is
// already evaluated"). withId fires immediately for a plugin that is
// already applied, which is what we want.
subprojects {
    listOf("com.android.library", "com.android.application").forEach { pluginId ->
        plugins.withId(pluginId) {
            val androidExtension = extensions.findByName("android")
            if (androidExtension is com.android.build.gradle.BaseExtension) {
                androidExtension.defaultConfig.externalNativeBuild.cmake.arguments(
                    "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,--build-id=none",
                    "-DCMAKE_MODULE_LINKER_FLAGS=-Wl,--build-id=none",
                    "-DCMAKE_EXE_LINKER_FLAGS=-Wl,--build-id=none",
                )
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

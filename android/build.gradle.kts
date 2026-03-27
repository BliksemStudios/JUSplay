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


// Patch missing namespace for flutter_dynamic_icon and other legacy plugins
// that are incompatible with Android Gradle Plugin 8+ out of the box.
gradle.projectsEvaluated {
    subprojects {
        if (plugins.hasPlugin("com.android.library")) {
            val androidExt = extensions.findByName("android")
            if (androidExt is com.android.build.gradle.LibraryExtension &&
                androidExt.namespace == null
            ) {
                when (project.name) {
                    "flutter_dynamic_icon" ->
                        androidExt.namespace =
                            "io.github.tastelessjolt.flutterdynamicicon"
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

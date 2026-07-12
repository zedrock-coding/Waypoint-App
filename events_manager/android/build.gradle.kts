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
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            
            // Fix for libraries missing namespace (like isar_flutter_libs)
            if (android.namespace == null) {
                val manifestFile = project.file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val manifestXml = manifestFile.readText()
                    val packageMatch = Regex("package=\"([^\"]+)\"").find(manifestXml)
                    if (packageMatch != null) {
                        android.namespace = packageMatch.groupValues[1]
                    }
                }
            }

            // Fix for "resource android:attr/lStar not found" error
            // This happens when dependencies require a higher compileSdkVersion than what the library specifies.
            // Forcing compileSdkVersion to 34 or higher usually resolves this.
            if (android.compileSdkVersion != "android-35") {
                android.compileSdkVersion("android-35")
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

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

    // ────────────────────────────────────────────────────────────
    // Force every Android library plugin to compile against 36+. Some
    // still ship with compileSdk=34 while their transitive deps demand
    // 36 (flutter_plugin_android_lifecycle, connectivity_plus, ...),
    // which trips CheckAarMetadata.
    //
    // Registered inside the SAME `subprojects { }` block that sets
    // `layout.buildDirectory`, BEFORE the `evaluationDependsOn(":app")`
    // block below — otherwise the target projects are already
    // evaluated and Gradle rejects the callback.
    // See gray_part_pitfalls.md §2, §7.
    // ────────────────────────────────────────────────────────────
    afterEvaluate {
        extensions
            .findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.apply {
                if ((compileSdk ?: 0) < 36) {
                    compileSdk = 36
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

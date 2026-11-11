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
buildscript {
    // Required for the classpath dependencies below — a buildscript block
    // does not inherit the allprojects repositories.
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.firebase:firebase-crashlytics-gradle:3.0.2")
        classpath("com.google.firebase:perf-plugin:1.4.2")
    }
}
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

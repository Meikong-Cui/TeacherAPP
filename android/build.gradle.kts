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
// 兼容补丁：老插件（如 flutter_app_badger 1.5.0，2021 年后未再更新）在新
// AGP 下有两处硬伤，这里在子项目求值完成后统一兜底：
//   1) 没声明 namespace（AGP 8+ 必须）→ 从 AndroidManifest.xml 的 package 补；
//   2) compileSdk 太低但 sourceCompatibility 是 Java 9+ → 抬到 34。
// 用 afterEvaluate 是因为插件自己的 android{} 块会覆盖 apply 时设的值，
// 必须等它求值完再改。**本块必须放在下方 evaluationDependsOn 块之前**：
// evaluationDependsOn 会立即触发 :app 求值，之后再注册 afterEvaluate
// 会报 "project is already evaluated"。
subprojects {
    project.afterEvaluate {
        val ext = project.extensions.findByName("android")
                as? com.android.build.gradle.LibraryExtension ?: return@afterEvaluate
        if (ext.namespace.isNullOrEmpty()) {
            val manifestFile = project.file("src/main/AndroidManifest.xml")
            if (manifestFile.exists()) {
                val doc = javax.xml.parsers.DocumentBuilderFactory.newInstance()
                    .newDocumentBuilder()
                    .parse(manifestFile)
                val pkg = doc.documentElement.getAttribute("package")
                if (!pkg.isNullOrEmpty()) {
                    ext.namespace = pkg
                    logger.lifecycle("== auto-namespace: ${project.name} -> $pkg")
                }
            }
        }
        if ((ext.compileSdk ?: 0) < 34) {
            ext.compileSdk = 34
            logger.lifecycle("== auto-compileSdk: ${project.name} -> 34")
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

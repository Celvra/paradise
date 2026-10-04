package fan.x0.para.workspace

import android.system.Os
import java.io.File
import java.nio.file.Files

/**
 * Removes an extracted rootfs tree.
 *
 * Tarballs carry directories the app cannot list or unlink children from
 * (read-only or sticky modes), and a plain recursive delete dies with EACCES
 * on the first one. Dart has no chmod, so the fix has to live here: modes are
 * corrected on the way down, symlinks are deleted as links and never followed.
 */
internal object RootfsRemover {
    fun remove(dir: File) {
        require(dir.isDirectory) { "not a directory: ${dir.absolutePath}" }
        removeTree(dir)
        if (dir.exists() && !dir.delete()) {
            throw IllegalStateException("could not remove ${dir.absolutePath}")
        }
    }

    private fun removeTree(dir: File) {
        // owner rwx: listing needs r+x, unlinking children needs w+x
        chmod(dir, 0b111_000_000)
        val children = dir.listFiles() ?: return
        for (child in children) {
            when {
                Files.isSymbolicLink(child.toPath()) -> child.delete()
                child.isDirectory -> {
                    removeTree(child)
                    child.delete()
                }
                else -> child.delete()
            }
        }
    }

    private fun chmod(file: File, mode: Int) {
        try {
            Os.chmod(file.absolutePath, mode)
        } catch (_: Exception) {
        }
    }
}

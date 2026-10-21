# Scope file access to the drop callback

File handles will remain readable only while the awaited drop callback is active. Callers must consume or copy data before the callback returns if they need it later; the package will not create hidden retained copies or temporary storage.

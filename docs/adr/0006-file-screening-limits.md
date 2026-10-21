# Limit file count and per-file size

Version 1 will expose `maxFiles` and `maxFileSizeBytes`. `maxFiles` counts files that pass the other configured constraints, in source order; strings do not count. `maxFileSizeBytes` caps each file separately. If final size is unavailable while a size limit is active, reject that file. Version 1 will not impose an aggregate batch-size limit. MIME and item-type filters also apply to string payloads.

# Accept files and string payloads; defer directories

Version 1 will accept incoming files and MIME-tagged plain-text, HTML, and URI-list values, but not directory items. URI values remain data and are not fetched; defer directories because their access and permission rules vary by platform.

All transfers are copy operations. Version 1 will not request move or link behavior, and will not remove source items.

# 0.13.6 (2017-09-19)

Fix vulnerabilities:

* Fix XSS & CSRF vulnerabilities - CVE-2017-14506 (reported by Quitten)

# 0.13.5 (2017-01-14)

Fixes:

* disk_cache.rb: ignore Errno::ENOENT, and EOFError. There is a possibility that the file is removed by another process after checking File.exist?.

# 0.13.4 (2016-10-25)

Fixes:

* Fix allow_remote_failure was not working in proxy/file_handler

# 0.13.3 (2016-10-13)

Enhancements:

* Add force_rebuild query parameter option to reindex route #244 (thanks to kbacha)

# 0.13.2 (2016-10-13)

Enhancements:

* Add the allow_upload config #247 (thanks to CAFxX)

Fixes:

* Atomic writes proxy latest specs #245 (thanks to dsolsona)

# tests/unit/test_version_info.gd
extends GutTest

func test_version():
	assert_eq(VersionInfo.version(), "0.1.2")

func test_commit_sha_type():
	var sha = VersionInfo.commit_sha()
	assert_true(sha is String)

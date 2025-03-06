-- /dev/null
+++ b/luci-app-oaf/root/usr/share/rpcd/acl.d/luci-app-oaf.json
@@ -0,0 +1,11 @@
+{
+	"luci-app-oaf": {
+		"description": "Grant UCI access for luci-app-oaf",
+		"read": {
+			"uci": [ "appfilter" ]
+		},
+		"write": {
+			"uci": [ "appfilter" ]
+		}
+	}
+}

--- a/oaf/Makefile
+++ b/oaf/Makefile
@@ -23,7 +23,7 @@ define KernelPackage/oaf/description
 endef
 
 
-EXTRA_CFLAGS:=-Wno-declaration-after-statement -Wno-strict-prototypes -Wno-unused-variable -Wno-implicit-fallthrough -Wno-missing-braces -Wno-parentheses -Wno-format
+EXTRA_CFLAGS:=-Wno-declaration-after-statement -Wno-strict-prototypes -Wno-unused-variable -Wno-implicit-fallthrough -Wno-missing-braces -Wno-parentheses -Wno-format -Wno-incompatible-pointer-types
 
 

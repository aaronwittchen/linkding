kubectl exec -it -n linkding postgres-0 -- psql -U linkding -d linkding

-- Show all tables
\dt
linkding=# \dt
List of relations
Schema | Name | Type | Owner
--------+----------------------------+-------+----------
public | auth_group | table | linkding
public | auth_group_permissions | table | linkding
public | auth_permission | table | linkding
public | auth_user | table | linkding
public | auth_user_groups | table | linkding
public | auth_user_user_permissions | table | linkding
public | authtoken_token | table | linkding
public | bookmarks_bookmark | table | linkding
public | bookmarks_bookmark_tags | table | linkding
public | bookmarks_bookmarkasset | table | linkding
public | bookmarks_bookmarkbundle | table | linkding
public | bookmarks_feedtoken | table | linkding
public | bookmarks_globalsettings | table | linkding
public | bookmarks_tag | table | linkding
public | bookmarks_toast | table | linkding
public | bookmarks_userprofile | table | linkding
public | django_admin_log | table | linkding
public | django_content_type | table | linkding
public | django_migrations | table | linkding
public | django_session | table | linkding
(20 rows)

-- Describe a table (columns, types, constraints)
\d tablename

-- List databases
\l

-- Show current database
SELECT current_database();

-- Show current user
SELECT current_user;

SELECT id, name FROM bookmarks_tag;

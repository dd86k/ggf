# ggf - Windows disk information tool

A small, lazily-written, df-like, Windows disk information tool.

## Examples

```
> ggf
DRIVE  TYPE            USED       FREE      TOTAL  TYPE    NAME
C:     Fixed       162.13 G    60.91 G   223.03 G  NTFS    SYSTEM
D:     Fixed         2.26 T     1.38 T     3.64 T  NTFS    DATA
E:     Removable    19.41 G    39.54 G    58.95 G  exFAT   VENTOY
G:     Optical
K:     Fixed         1.49 T   336.32 G     1.82 T  NTFS    BACKUP
```

```
>ggf -P
DRIVE  USAGE
C:     [============================================================                      ] 72.7%
D:     [===================================================                               ] 62.0%
E:     [==========================                                                        ] 32.9%
G:
K:     [====================================================================              ] 81.9%
```

```
>ggf -M
DRIVE  SERIAL     MAX PATH
C:     DEEE-E7BC       255
D:     2C56-E20B       255
E:     4E21-0000       255
G:
K:     548B-2228       255
```

```
>ggf -F
DRIVE  FEATURES
C:     CASE_SENSITIVE_SEARCH CASE_PRESERVED_NAMES PERSISTENT_ACLS NAMED_STREAMS EXTENDED_ATTRIBUTES
HARD_LINKS OBJECT_ID OPEN_BY_FILE_ID REPARSE_POINTS SPARSE_FILES TRANSACTIONS USN_JOURNAL UNICODE COMPRESSION QUOTAS
D:     CASE_SENSITIVE_SEARCH CASE_PRESERVED_NAMES PERSISTENT_ACLS NAMED_STREAMS EXTENDED_ATTRIBUTES
HARD_LINKS OBJECT_ID OPEN_BY_FILE_ID REPARSE_POINTS SPARSE_FILES TRANSACTIONS USN_JOURNAL UNICODE COMPRESSION QUOTAS
E:     CASE_PRESERVED_NAMES ENCRYPTION UNICODE
G:
K:     CASE_SENSITIVE_SEARCH CASE_PRESERVED_NAMES PERSISTENT_ACLS NAMED_STREAMS EXTENDED_ATTRIBUTES
HARD_LINKS OBJECT_ID OPEN_BY_FILE_ID REPARSE_POINTS SPARSE_FILES TRANSACTIONS USN_JOURNAL UNICODE QUOTAS
```
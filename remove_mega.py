import re
import os

filepath = r'c:\dev\testapp\lib\main.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. megaApiBase
content = content.replace('const String megaApiBase = "https://g.api.mega.co.nz";', '/* const String megaApiBase = "https://g.api.mega.co.nz"; */')

# 2. enum removals
content = content.replace('enum PhotoSource { oneDrive, dropbox, googleDrive, box, pCloud, mega }', 'enum PhotoSource { oneDrive, dropbox, googleDrive, box, pCloud /*, mega*/ }')
content = content.replace('enum FilterSource { all, oneDrive, dropbox, googleDrive, box, pCloud, mega }', 'enum FilterSource { all, oneDrive, dropbox, googleDrive, box, pCloud /*, mega*/ }')

# 3. session vars
content = content.replace('  String? _megaSessionId; // ✅ MEGA: Session ID token', '  // String? _megaSessionId; // ✅ MEGA: Session ID token')
content = content.replace('  bool _megaError = false; // ✅ MEGA ADDED', '  // bool _megaError = false; // ✅ MEGA ADDED')

# 4. Mega Cloud Integration Block
block_start = content.find('// =============================================================================\n// --- MEGA CLOUD INTEGRATION ---')
block_end = content.find('// END MEGA INTEGRATION\n// =============================================================================')
if block_end != -1:
    block_end += len('// END MEGA INTEGRATION\n// =============================================================================')

if block_start != -1 and block_end != -1:
    mega_block = content[block_start:block_end]
    content = content[:block_start] + '/* \n' + mega_block + '\n*/' + content[block_end:]

# 5. _loadStoredTokens
content = re.sub(r'(final String\? megaSession = await secureStorage\.read\(key: _userKey\(\'mega_session_id\'\)\);)', r'// \1', content)
content = re.sub(r'(_megaSessionId = megaSession;)', r'// \1', content)

# 6. Condition in _loadStoredTokens
content = content.replace('&& pCloudToken == null && megaSession == null)', '&& pCloudToken == null /* && megaSession == null */)')

# 7. Other simple references
content = re.sub(r'(_megaError = false;)', r'// \1', content)

# 8. Mega checking in if (megaSession != null)
content = content.replace('if (megaSession != null) {', '/* if (megaSession != null) {')
content = content.replace('        _megaSessionId = megaSession;\n      }\n    }', '        _megaSessionId = megaSession;\n      }\n    } */')

# 9. _handleLogout
content = content.replace('    // ✅ MEGA: Delete Mega session\n    await secureStorage.delete(key: _userKey(\'mega_session_id\'));', '    /* ✅ MEGA: Delete Mega session\n    await secureStorage.delete(key: _userKey(\'mega_session_id\')); */')
content = re.sub(r'(_megaSessionId = null; // ✅ MEGA)', r'// \1', content)
content = re.sub(r'(_megaError = false; // ✅ MEGA)', r'// \1', content)

# 10. errorServices
content = content.replace('if (_megaError) errorServices.add(\'Mega\'); // ✅ MEGA', '// if (_megaError) errorServices.add(\'Mega\'); // ✅ MEGA')
content = content.replace('if (_megaSessionId != null && !_megaError) connectedServices.add(\'Mega\'); // ✅ MEGA', '// if (_megaSessionId != null && !_megaError) connectedServices.add(\'Mega\'); // ✅ MEGA')

# 11. MEGA FILTER
filter_old = """      // ✅ MEGA FILTER:
      if (_currentSourceFilter == FilterSource.mega &&
          item.source != PhotoSource.mega) return false;"""
filter_new = """      /* ✅ MEGA FILTER:
      if (_currentSourceFilter == FilterSource.mega &&
          item.source != PhotoSource.mega) return false; */"""
content = content.replace(filter_old, filter_new)

# 12. _fetchAllPhotos
fetch_mega_old = """    // ✅ ADDED MEGA HERE
    if (firstPage && _megaSessionId != null && !_megaError)
      _fetchMegaPhotos(),"""
content = content.replace(fetch_mega_old, '/*\n' + fetch_mega_old + '\n*/')

# 13. _getDownloadUrl
get_url_mega_old = """    if (item.source == PhotoSource.mega &&
        (_megaSessionId == null || _megaError)) return null;"""
content = content.replace(get_url_mega_old, '/*\n' + get_url_mega_old + '\n*/')

get_url_mega_2_old = """    } else if (item.source == PhotoSource.mega) {
      // Mega download URL is stored in item.downloadUrl during fetch
      // If it's null or expired, we must fetch a fresh one
      url = await _getMegaDownloadUrl(item.id);
    }"""
content = content.replace(get_url_mega_2_old, '/*\n' + get_url_mega_2_old + '\n*/')

# 14. counts
content = content.replace('if (_megaSessionId != null) connectedCount++;', '// if (_megaSessionId != null) connectedCount++;')
content = content.replace('if (serviceName == \'Mega\' && _megaSessionId != null) isRefreshing = true;', '// if (serviceName == \'Mega\' && _megaSessionId != null) isRefreshing = true;')
content = content.replace('if (_megaSessionId != null && !_megaError) connectedCount++;', '// if (_megaSessionId != null && !_megaError) connectedCount++;')

# 15. UI Cloud login row
cloud_row_old = """                  // Mega (Locked if slot full)
                  if (!(_pCloudAccessToken != null && isSlotFull && _megaSessionId == null)) // Hide if another is connected and slot is full
                    _buildCloudLoginRow(
                      "Mega",
                      _megaSessionId != null && !_megaError,
                      isSlotFull && _megaSessionId == null, // LOCKED?
                      () => _handleCloudLogin('Mega', _loginToMega)),"""
content = content.replace(cloud_row_old, '/*\n' + cloud_row_old + '\n*/')

# 16. App drawer
drawer_1_old = """              // 5. Mega
              if (_megaSessionId != null && !_megaError)
                ListTile(
                  leading: const Icon(Icons.cloud, color: Color(0xFFD9173A)),
                  title: const Text("Mega"),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      _logoutFromMega();
                      Navigator.pop(context);
                    },
                  ),
                ),"""
content = content.replace(drawer_1_old, '/*\n' + drawer_1_old + '\n*/')

drawer_2_old = """                  _pCloudAccessToken == null && _megaSessionId == null)"""
drawer_2_new = """                  _pCloudAccessToken == null /* && _megaSessionId == null */)"""
content = content.replace(drawer_2_old, drawer_2_new)

# 17. Setting screen
setting_1_old = """          // 6. Mega
          if (!(_pCloudAccessToken != null && isSlotFull && _megaSessionId == null)) // Hide if another is connected and slot is full
            ListTile(
              leading: const Icon(Icons.cloud, color: Color(0xFFD9173A)),
              title: const Text("Mega"),
              subtitle: Text(_megaSessionId != null && !_megaError ? "Connected" : "Not connected"),
              trailing: _megaSessionId != null && !_megaError
                ? IconButton(icon: const Icon(Icons.close), onPressed: _logoutFromMega)
                : IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _loginToMega),
            ),"""
content = content.replace(setting_1_old, '/*\n' + setting_1_old + '\n*/')

setting_empty_old = """        _megaSessionId == null && // ✅ MEGA"""
content = content.replace(setting_empty_old, '/*\n' + setting_empty_old + '\n*/')

setting_empty_2_old = """        !_megaError; // ✅ MEGA"""
content = content.replace(setting_empty_2_old, '/*\n' + setting_empty_2_old + '\n*/')

# Save updated content
with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Done processing")

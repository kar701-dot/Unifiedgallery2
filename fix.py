import sys

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_content = """        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13, // Slightly larger
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // --- MODIFIED: BuildBody handles both grouped and flat lists ---
  Widget _buildSettingsPage() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? null : Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black
        ),
        title: Text(
            "Settings",
            style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black
            )
        ),
      ),
      // âœ… FIX: Wrap the body in StatefulBuilder to allow the toggle to update visually
      body: StatefulBuilder(
        builder: (BuildContext context, StateSetter setSettingsState) {
          return ListView(
            children: [
              // --- THEME SETTINGS ---
              ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: const Text("Application Theme"),
                subtitle: const Text("Choose default theme"),
                trailing: DropdownButton<ThemeMode>(
                  value: themeNotifier.value,
                  onChanged: (ThemeMode? newMode) async {
                    if (newMode != null) {
                      themeNotifier.value = newMode;
                      await _saveThemePreference(newMode);
                      setSettingsState(() {});
                      setState(() {});
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                  ],
                ),
              ),

              // --- CACHING SETTINGS ---
              SwitchListTile(
                secondary: const Icon(Icons.cached),
                title: const Text("Enable Image Caching"),
                subtitle: const Text("Load images faster using local storage"),
                value: _useCaching,
                onChanged: (bool value) {
                  // 1. Update the Main App State (Logic)
                  setState(() => _useCaching = value);
                  
                  // 2. Update the Settings Page UI (Visual Toggle)
                  setSettingsState(() {});

                  // 3. Save preference
                  _saveCachingPreference(value);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: const Text("Clear image cache"),
                onTap: () {
                  _clearImageCache();
                },
              ),

              // --- BIN BEHAVIOR ---
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                child: Text("Bin & Deletion",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold
                  )
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.delete_forever_outlined),
                title: const Text("Delete from Cloud/Device"),
                subtitle: Text(
                  _binDeleteFromCloud
                    ? "Permanently removes files from cloud storage and device gallery when deleted from Bin"
                    : "Removes files from this app only — files stay on the cloud/device",
                ),
                value: _binDeleteFromCloud,
                onChanged: (bool value) {
                  _saveBinDeletePreference(value);
                  setSettingsState(() {});
                },
              ),

              // --- AI & SEARCH ---
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                child: Text(
                  "AI & Search",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Rescan All Photos tile
              ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: const Text("Re-run AI tagging"),
                subtitle: const Text(
                  "Re-run AI tagging, object detection & OCR on all photos.",
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _isAiScanning
                    ? null // Disabled while a scan is already running
                    : () async {
                        // Confirmation dialog
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Rescan All Photos?"),
                            content: const Text(
                              "This will re-analyse every photo with the latest AI "
                              "models (image labels, object detection, and OCR text "
                              "recognition).\\n\\n"
                              "The scan runs in the background and may take a few "
                              "minutes depending on your library size. "
                              "Your existing tags will be refreshed.",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text("Cancel"),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text("Start Rescan"),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true && mounted) {
                          final userId = widget.firebaseUser.uid;
                          // Mark every record as needing a rescan
                          await assetRepository.markAllNeedsRescan(userId);

                          // Kick off the background scan immediately
                          _startBackgroundAiScan();

                          if (mounted) {
                            Navigator.pop(context); // Close settings page
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "✨ AI rescan started! New tags will appear as photos are processed.",
                                ),
                                duration: Duration(seconds: 4),
                              ),
                            );
                          }
                        }
                      },
              ),

              const SizedBox(height: 16),
            ],

          );
        },
      ),
    );
  }
"""

new_lines = lines[:7794] + [l + '\n' for l in new_content.split('\n')] + lines[7987:]

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print('Success')

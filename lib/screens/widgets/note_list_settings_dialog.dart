import 'package:flutter/material.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/core/theme/app_theme.dart';

class NoteListSettingsDialog extends StatelessWidget {
  const NoteListSettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: MnoteApp.themeModeNotifier,
      builder: (context, currentMode, _) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.settings_rounded, color: theme.colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('การตั้งค่า', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'โหมดการแสดงผล (Theme)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_rounded, color: Colors.teal, size: 18),
                          label: Text('ตามเครื่อง'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.wb_sunny_rounded, color: Colors.orange, size: 18),
                          label: Text('สว่าง'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_rounded, color: Colors.indigoAccent, size: 18),
                          label: Text('มืด'),
                        ),
                      ],
                      selected: {currentMode},
                      onSelectionChanged: (newSelection) {
                        MnoteApp.themeModeNotifier.value = newSelection.first;
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      currentMode == ThemeMode.system
                          ? 'ค่าเริ่มต้น: ปรับมืด/สว่างอัตโนมัติตามโหมดของเครื่อง'
                          : (currentMode == ThemeMode.dark ? 'เปิดใช้งานโหมดมืด' : 'เปิดใช้งานโหมดสว่าง'),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'ฟอนต์ตัวอักษร (Typography)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<AppFontFamily>(
                    valueListenable: MnoteApp.fontNotifier,
                    builder: (context, currentFont, _) {
                      return Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<AppFontFamily>(
                            isExpanded: true,
                            value: currentFont,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            items: AppFontFamily.values.map((f) {
                              return DropdownMenuItem<AppFontFamily>(
                                value: f,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.font_download_rounded,
                                      size: 18,
                                      color: f == currentFont
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      f.label,
                                      style: TextStyle(
                                        fontFamily: f.familyName,
                                        fontWeight: f == currentFont ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (newFont) {
                              if (newFont != null) {
                                MnoteApp.fontNotifier.value = newFont;
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'เลือกฟอนต์โมเดิร์นที่เหมาะสมกับการอ่านและเขียนโน้ตภาษาไทย',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'MNote v1.0.0 • Local-First Markdown Workspace',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('เสร็จสิ้น'),
            ),
          ],
        );
      },
    );
  }
}

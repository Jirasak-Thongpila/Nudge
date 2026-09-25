import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/audio_recorder.dart';
import '../theme/app_theme.dart';
import '../widgets/theme_toggle_button.dart';

class AddTaskScreen extends StatefulWidget {
  final ApiClient apiClient;

  const AddTaskScreen({super.key, required this.apiClient});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  // Smart AI Input State
  final _smartPromptController = TextEditingController();
  final _platformRecorder = PlatformAudioRecorder();
  bool _isProcessingAI = false;
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  // Manual Form State
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _estimatedMinutesController = TextEditingController(text: '30');
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 18, minute: 0);
  int _importance = 3;
  bool _isManualSubmitting = false;

  String? _errorMessage;

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _smartPromptController.dispose();
    _titleController.dispose();
    _estimatedMinutesController.dispose();
    super.dispose();
  }

  DateTime get _combinedDeadline {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // --- Voice Recording Flow ---
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Stop recording
      _recordingTimer?.cancel();
      setState(() {
        _isRecording = false;
        _isProcessingAI = true;
        _errorMessage = null;
      });

      try {
        final audioBase64 = await _platformRecorder.stop();
        if (audioBase64 == null || audioBase64.isEmpty) {
          throw Exception('ไม่สามารถบันทึกไฟล์เสียงได้ กรุณาลองใหม่อีกครั้ง');
        }

        await _processQuickAddAudio(audioBase64: audioBase64);
      } catch (e) {
        if (mounted) {
          setState(() {
            _isProcessingAI = false;
            _errorMessage = e.toString().replaceAll('Exception: ', '');
          });
        }
      }
    } else {
      // Start recording
      setState(() {
        _errorMessage = null;
      });

      final started = await _platformRecorder.start();
      if (!started) {
        setState(() {
          _errorMessage =
              'ไม่สามารถเปิดใช้งานไมโครโฟนได้ กรุณาตรวจสอบสิทธิ์การใช้งานบนอุปกรณ์หรือบราวเซอร์';
        });
        return;
      }

      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          _recordingSeconds++;
        });

        // Auto stop after 60 seconds
        if (_recordingSeconds >= 60) {
          _toggleRecording();
        }
      });
    }
  }

  // --- AI Text Quick Add ---
  Future<void> _processQuickAddText({bool confirmed = false}) async {
    final text = _smartPromptController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorMessage = 'กรุณาพิมพ์ข้อความบอกงาน เช่น "พรุ่งนี้ 9 โมงส่งรายงาน"';
      });
      return;
    }

    setState(() {
      _isProcessingAI = true;
      _errorMessage = null;
    });

    try {
      final res = await widget.apiClient.quickAddTask(text: text, confirmed: confirmed);

      if (res['notTask'] == true) {
        setState(() {
          _isProcessingAI = false;
          _errorMessage = res['replyMessage'] ??
              'ยังไม่สามารถระบุงานได้ กรุณาระบุชื่องานและเวลาให้ชัดเจนขึ้นครับ';
        });
        return;
      }

      if (res['duplicate'] == true && !confirmed) {
        setState(() {
          _isProcessingAI = false;
        });
        if (mounted) {
          final existing = res['existingTask'];
          final duplicateTitle = existing?['title'] ?? 'งานที่คล้ายกัน';
          final shouldProceed = await _showDuplicateWarningDialog(duplicateTitle);
          if (shouldProceed == true) {
            _processQuickAddText(confirmed: true);
          }
        }
        return;
      }

      final taskData = res['data'];
      final title = taskData?['title'] ?? text;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✅ บันทึก Task สำเร็จ: "$title"',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingAI = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  // --- AI Audio Quick Add ---
  Future<void> _processQuickAddAudio({
    required String audioBase64,
    bool confirmed = false,
  }) async {
    try {
      final res = await widget.apiClient.quickAddAudioTask(
        audioBase64: audioBase64,
        confirmed: confirmed,
      );

      if (res['notTask'] == true) {
        setState(() {
          _isProcessingAI = false;
          _errorMessage = res['replyMessage'] ??
              'ฟังเสียงไม่ชัดเจนหรือยังไม่ใช่งาน กรุณาลองใหม่อีกครั้งครับ';
        });
        return;
      }

      if (res['duplicate'] == true && !confirmed) {
        setState(() {
          _isProcessingAI = false;
        });
        if (mounted) {
          final existing = res['existingTask'];
          final duplicateTitle = existing?['title'] ?? 'งานที่คล้ายกัน';
          final shouldProceed = await _showDuplicateWarningDialog(duplicateTitle);
          if (shouldProceed == true) {
            _processQuickAddAudio(audioBase64: audioBase64, confirmed: true);
          }
        }
        return;
      }

      final taskData = res['data'];
      final title = taskData?['title'] ?? 'งานใหม่';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✅ บันทึกจากเสียงสำเร็จ: "$title"',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingAI = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<bool?> _showDuplicateWarningDialog(String existingTitle) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('พบงานที่ใกล้เคียงกัน'),
          ],
        ),
        content: Text(
          'คุณมีงาน "$existingTitle" อยู่ในระบบแล้ว\n\nต้องการบันทึกเป็นงานใหม่ซ้ำหรือไม่?',
          style: const TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
            ),
            child: const Text('บันทึกซ้ำ'),
          ),
        ],
      ),
    );
  }

  // --- Manual Form Submit ---
  Future<void> _submitManual() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isManualSubmitting = true;
      _errorMessage = null;
    });

    try {
      final estimatedMinutes = int.parse(_estimatedMinutesController.text.trim());
      await widget.apiClient.createTask(
        title: _titleController.text.trim(),
        deadline: _combinedDeadline,
        importance: _importance,
        estimatedMinutes: estimatedMinutes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ บันทึก Task สำเร็จ: "${_titleController.text.trim()}"'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isManualSubmitting = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dateStr =
        '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';
    final timeStr =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: colors.bgCanvas,
      appBar: AppBar(
        title: Text(
          'เพิ่ม Task ใหม่',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: const [
          ThemeToggleButton(),
          SizedBox(width: 8),
        ],
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error Message
            if (_errorMessage != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.isDark ? const Color(0xFF2E1015) : const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: colors.isDark ? AppColors.roseLight : AppColors.rose,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: colors.isDark ? AppColors.roseLight : const Color(0xFFBE123C),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 1. Smart AI Box (LINE-style)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.cardRadius),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: colors.isDark ? 0.4 : 0.25),
                  width: 1.5,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.cardRadius),
                  gradient: LinearGradient(
                    colors: [
                      colors.isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF),
                      colors.cardSurface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: colors.cardShadow,
                ),
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            boxShadow: AppShadows.primaryGlow,
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'บันทึกด่วนด้วย AI (แบบ LINE)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: colors.textPrimary,
                                ),
                              ),
                              Text(
                                'พิมพ์ข้อความหรือกดไมค์พูดภาษาไทยได้ทันที',
                                style: TextStyle(fontSize: 12, color: colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Voice Recording Banner if recording
                    if (_isRecording) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: colors.isDark ? const Color(0xFF2E1015) : const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.rose.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.isDark ? AppColors.roseLight : AppColors.rose,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'กำลังฟังเสียงพูด... (${_recordingSeconds}s)',
                                style: TextStyle(
                                  color: colors.isDark ? AppColors.roseLight : const Color(0xFFBE123C),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _toggleRecording,
                              icon: Icon(
                                Icons.stop,
                                color: colors.isDark ? AppColors.roseLight : AppColors.rose,
                                size: 18,
                              ),
                              label: Text(
                                'เสร็จสิ้น',
                                style: TextStyle(
                                  color: colors.isDark ? AppColors.roseLight : const Color(0xFFBE123C),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Input TextField + Mic + Send Button
                    TextField(
                      controller: _smartPromptController,
                      enabled: !_isProcessingAI && !_isRecording,
                      maxLines: 2,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _processQuickAddText(),
                      style: TextStyle(color: colors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'เช่น พรุ่งนี้ 9 โมงส่งรายงานวิจัย 4 ดาว 45 นาที',
                        hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
                        filled: true,
                        fillColor: colors.cardSurfaceElevated,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.buttonRadius),
                          borderSide: BorderSide(color: colors.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.buttonRadius),
                          borderSide: BorderSide(color: colors.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.buttonRadius),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Microphone button
                            IconButton(
                              icon: Icon(
                                _isRecording ? Icons.stop_circle : Icons.mic_rounded,
                                color: _isRecording ? AppColors.roseLight : AppColors.primaryLight,
                              ),
                              tooltip: _isRecording ? 'หยุดบันทึก' : 'พูดเพื่อบันทึกงาน',
                              onPressed: _isProcessingAI ? null : _toggleRecording,
                            ),
                            // Send / Add button
                            IconButton(
                              icon: _isProcessingAI
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
                                    )
                                  : const Icon(
                                      Icons.arrow_upward_rounded,
                                      color: AppColors.primaryLight,
                                    ),
                              tooltip: 'ส่งเพื่อสร้าง Task',
                              onPressed: (_isProcessingAI || _isRecording)
                                  ? null
                                  : () => _processQuickAddText(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick Prompt Chips
                    Text(
                      'ตัวอย่างคำสั่งด่วน:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'พรุ่งนี้ 9 โมงส่งรายงาน 4 ดาว',
                        'ส่งมินิโปรเจกต์วันศุกร์ 5 ดาว',
                        'อ่านหนังสือสอบ 2 ชม.',
                        'ทำการบ้าน 30 นาที',
                      ].map((sample) {
                        return ActionChip(
                          avatar: const Icon(Icons.flash_on_rounded, size: 14, color: AppColors.primaryLight),
                          label: Text(
                            sample,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          backgroundColor: colors.cardSurfaceElevated,
                          side: BorderSide(color: colors.cardBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          onPressed: (_isProcessingAI || _isRecording)
                              ? null
                              : () {
                                  _smartPromptController.text = sample;
                                  _processQuickAddText();
                                },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 2. Expandable Accordion for Manual Details
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.cardRadius),
                side: BorderSide(color: colors.cardBorder),
              ),
              color: colors.cardSurface,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: const Icon(Icons.tune_rounded, color: AppColors.primaryLight),
                  title: Text(
                    'หรือกรอกแบบฟอร์มละเอียด (Manual Input)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'กำหนดวัน เวลา และคะแนนความสำคัญด้วยตัวเอง',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _titleController,
                              style: TextStyle(color: colors.textPrimary),
                              decoration: InputDecoration(
                                labelText: 'ชื่องาน (Task Title)',
                                labelStyle: TextStyle(color: colors.textSecondary),
                                hintText: 'เช่น ทำรายงานวิจัย, Mini Project',
                                hintStyle: TextStyle(color: colors.textMuted),
                                fillColor: colors.cardSurfaceElevated,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.buttonRadius),
                                  borderSide: BorderSide(color: colors.cardBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.buttonRadius),
                                  borderSide: BorderSide(color: colors.cardBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.buttonRadius),
                                  borderSide: const BorderSide(color: AppColors.primary),
                                ),
                                prefixIcon: Icon(Icons.task_alt, color: colors.textMuted),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'กรุณากรอกชื่องาน';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Deadline (กำหนดส่ง)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickDate,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: colors.textPrimary,
                                      backgroundColor: colors.cardSurfaceElevated,
                                      side: BorderSide(color: colors.cardBorder),
                                    ),
                                    icon: const Icon(Icons.calendar_today, size: 18, color: AppColors.primaryLight),
                                    label: Text(dateStr),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickTime,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: colors.textPrimary,
                                      backgroundColor: colors.cardSurfaceElevated,
                                      side: BorderSide(color: colors.cardBorder),
                                    ),
                                    icon: const Icon(Icons.access_time, size: 18, color: AppColors.primaryLight),
                                    label: Text(timeStr),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'ระดับความสำคัญ (Importance)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: List.generate(5, (index) {
                                final level = index + 1;
                                final isSelected = _importance == level;
                                return ChoiceChip(
                                  label: Text('$level ⭐'),
                                  selected: isSelected,
                                  selectedColor: AppColors.primary,
                                  backgroundColor: colors.cardSurfaceElevated,
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.white : colors.textSecondary,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  side: BorderSide(
                                    color: isSelected ? AppColors.primary : colors.cardBorder,
                                  ),
                                  onSelected: (_) {
                                    setState(() {
                                      _importance = level;
                                    });
                                  },
                                );
                              }),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'เวลาที่คาดว่าจะใช้ (นาที)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _estimatedMinutesController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: colors.textPrimary),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.buttonRadius),
                                  borderSide: BorderSide(color: colors.cardBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.buttonRadius),
                                  borderSide: BorderSide(color: colors.cardBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.buttonRadius),
                                  borderSide: const BorderSide(color: AppColors.primary),
                                ),
                                fillColor: colors.cardSurfaceElevated,
                                suffixText: 'นาที',
                                suffixStyle: TextStyle(color: colors.textSecondary),
                                prefixIcon: Icon(Icons.timer_outlined, color: colors.textMuted),
                              ),
                              validator: (value) {
                                final parsed = int.tryParse(value ?? '');
                                if (parsed == null || parsed <= 0) {
                                  return 'กรุณากรอกเวลาเป็นจำนวนนาทีที่มากกว่า 0';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [15, 30, 45, 60, 120].map((mins) {
                                return ActionChip(
                                  label: Text(
                                    '$mins นาที',
                                    style: TextStyle(color: colors.textPrimary, fontSize: 12),
                                  ),
                                  backgroundColor: colors.cardSurfaceElevated,
                                  side: BorderSide(color: colors.cardBorder),
                                  onPressed: () {
                                    _estimatedMinutesController.text = mins.toString();
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppRadius.buttonRadius),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                                ),
                                boxShadow: AppShadows.primaryGlow,
                              ),
                              child: FilledButton(
                                onPressed: _isManualSubmitting ? null : _submitManual,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.buttonRadius),
                                  ),
                                ),
                                child: _isManualSubmitting
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'บันทึก Task แบบฟอร์ม',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/log_entry.dart';
// Note: flutter_tts could be used for text-to-speech, but sticking to basic UI and simulated audio for now.
import 'package:flutter/services.dart';

class ResponderLogScreen extends StatefulWidget {
  final VoidCallback onBack;
  final List<LogEntry> logEntries;
  final VoidCallback onExportLog;

  const ResponderLogScreen({
    Key? key,
    required this.onBack,
    required this.logEntries,
    required this.onExportLog,
  }) : super(key: key);

  @override
  _ResponderLogScreenState createState() => _ResponderLogScreenState();
}

class _ResponderLogScreenState extends State<ResponderLogScreen> {
  String? _playingId;

  void _handlePlayAudio(LogEntry entry) {
    HapticFeedback.lightImpact();
    if (_playingId == entry.id) {
      setState(() {
        _playingId = null;
      });
      return;
    }

    setState(() {
      _playingId = entry.id;
    });

    // Simulate audio playing
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _playingId == entry.id) {
        setState(() {
          _playingId = null;
        });
      }
    });
  }

  void _handleStopAudio(String entryId) {
    HapticFeedback.lightImpact();
    setState(() {
      _playingId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          color: const Color(0xFF1976D2),
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, left: 16, right: 16, bottom: 16),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.chevron_left, color: Colors.white, size: 26),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      hoverColor: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Patient Symptom Log', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('FSL Translation History', style: TextStyle(fontSize: 14, color: Color(0xFFDBEAFE))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: widget.onExportLog,
                  icon: const Icon(Icons.download, size: 20, color: Colors.white),
                  label: const Text('Export Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.15),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Session Info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.access_time, size: 16, color: Color(0xFF475569)),
                  SizedBox(width: 8),
                  Text('Started 10:42 AM', style: TextStyle(fontSize: 14, color: Color(0xFF475569))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${widget.logEntries.length} phrases', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF15803D))),
              ),
            ],
          ),
        ),

        // Log Entries
        Expanded(
          child: widget.logEntries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.access_time, size: 32, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 16),
                      const Text('No Phrases Logged', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 8),
                      const Text('Detected phrases will appear here as they are translated', style: TextStyle(fontSize: 14, color: Color(0xFF475569))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 96),
                  itemCount: widget.logEntries.length,
                  itemBuilder: (context, index) {
                    final entry = widget.logEntries[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Timeline
                            Column(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: entry.severity == 'high' ? const Color(0xFFD32F2F) : const Color(0xFFFF9800),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                if (index < widget.logEntries.length - 1)
                                  Container(
                                    width: 2,
                                    height: 80,
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    color: const Color(0xFFE2E8F0),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(entry.time, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                                const SizedBox(width: 8),
                                                if (entry.severity == 'high')
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFEF2F2),
                                                      border: Border.all(color: const Color(0xFFFECACA)),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Row(
                                                      children: const [
                                                        Icon(Icons.error_outline, size: 10, color: Color(0xFFDC2626)),
                                                        SizedBox(width: 4),
                                                        Text('Critical', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFB91C1C))),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(entry.english, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                            const SizedBox(height: 4),
                                            Text(entry.tagalog, style: const TextStyle(fontSize: 14, color: Color(0xFF475569))),
                                            const SizedBox(height: 8),
                                            Text('${entry.words} words detected', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _playingId == entry.id ? _handleStopAudio(entry.id) : _handlePlayAudio(entry),
                                        icon: Icon(_playingId == entry.id ? Icons.stop : Icons.play_arrow, color: _playingId == entry.id ? Colors.white : const Color(0xFF1976D2)),
                                        style: IconButton.styleFrom(
                                          backgroundColor: _playingId == entry.id ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                          padding: const EdgeInsets.all(12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Footer
        Container(
          padding: EdgeInsets.only(top: 16, left: 16, right: 16, bottom: MediaQuery.of(context).padding.bottom + 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onBack,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Return to Translation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }
}

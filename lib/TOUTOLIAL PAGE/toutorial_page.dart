import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../FOTTER/CurvedRainbowBar.dart';

class TutorialPage extends StatefulWidget {
  const TutorialPage({super.key});

  @override
  State<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends State<TutorialPage> {
  final Stream<List<Map<String, dynamic>>> _tutorialStream = Supabase.instance.client
      .from('tutorials')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: true);

  // Optimized for opening the App directly
  Future<void> _launchYoutube(String videoId) async {
    final Uri appUrl = Uri.parse('vnd.youtube:$videoId');
    final Uri browserUrl = Uri.parse('https://www.youtube.com/watch?v=$videoId');

    try {
      // Check if YouTube App is installed
      if (await canLaunchUrl(appUrl)) {
        await launchUrl(appUrl);
      } else {
        // Fallback to browser
        await launchUrl(browserUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      await launchUrl(browserUrl, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOFTWARE TUTORIALS',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _tutorialStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final tutorials = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: tutorials.length,
            itemBuilder: (context, index) {
              final item = tutorials[index];
              final String vId = item['video_id'] ?? '';

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  // SHOW THUMBNAIL HERE
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.network(
                          'https://img.youtube.com/vi/$vId/0.jpg', // YouTube Thumbnail URL
                          width: 90,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, e, s) => Container(
                            width: 90, height: 60, color: Colors.grey[300],
                            child: const Icon(Icons.videocam_off),
                          ),
                        ),
                        const Icon(Icons.play_circle_outline, color: Colors.white70, size: 30),
                      ],
                    ),
                  ),
                  title: Text(item['title'] ?? 'No Title',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Tap to open in YouTube app'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => _launchYoutube(vId),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }
}
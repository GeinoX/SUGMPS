import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sugmps/routes.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  _HomepageState createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  File? profileImage;
  final ImagePicker picker = ImagePicker();

  Future<void> _pickimage() async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        profileImage = File(image.path);
      });
    }
  }

  Future<void> _launchURL(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open the link')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings, size: 30),
          ),
        ],
      ),
      backgroundColor: const Color.fromRGBO(255, 255, 255, 0.95),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Profile Container
              Container(
                padding: const EdgeInsets.all(15),
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF3C3889),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: _pickimage,
                          child: CircleAvatar(
                            radius: 30,
                            backgroundImage:
                                profileImage != null
                                    ? FileImage(profileImage!)
                                    : null,
                            child:
                                profileImage == null
                                    ? const Icon(Icons.person, size: 20)
                                    : null,
                          ),
                        ),
                        Column(
                          children: const [
                            Text(
                              'Njuh Leslie Cheghe',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'B.Sc Computer Science',
                              style: TextStyle(
                                color: Color(0xFFE77B22),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            Row(
                              children: const [
                                Text(
                                  'Attendance',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 30),
                                Text(
                                  '59%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 5,
                              width: 115,
                              child: LinearProgressIndicator(
                                value: 0.59,
                                backgroundColor: Colors.white,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(15),
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFE77B22),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Row(
                              children: const [
                                Text(
                                  'Fee',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 70),
                                Text(
                                  '89%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 5,
                              width: 115,
                              child: LinearProgressIndicator(
                                value: 0.89,
                                backgroundColor: Colors.white,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(15),
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFE77B22),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              // School Updates
              Row(
                children: const [
                  Text(
                    'School Updates',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Iteractionbox(
                    image: "assets/newspaper.png",
                    number: "3",
                    label: "News",
                    onTap: () => print("News clicked"),
                  ),
                  const SizedBox(width: 10),
                  _Iteractionbox(
                    image: "assets/calendar.png",
                    number: "5",
                    label: "Events",
                    onTap: () => print("Events clicked"),
                  ),
                  const SizedBox(width: 10),
                  _Iteractionbox(
                    image: "assets/megaphone.png",
                    number: "11",
                    label: "Bulletin",
                    onTap: () => print("Bulletin clicked"),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              // Academics
              Row(
                children: const [
                  Text(
                    'Academics',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _Iteractionbox(
                      image: "assets/assignment.png",
                      number: "3",
                      label: "Assignment",
                      onTap: () => print("Assignment clicked"),
                    ),
                    const SizedBox(width: 10),
                    _Iteractionbox(
                      image: "assets/certificate.png",
                      number: "6",
                      label: "Courses",
                      onTap:
                          () => {
                            Navigator.popAndPushNamed(
                              context,
                              AppRoutes.coursepage,
                            ),
                          },
                    ),
                    const SizedBox(width: 10),
                    _Iteractionbox(
                      image: "assets/immigration.png",
                      number: "2",
                      label: "Attendance",
                      onTap: () => print("Attendance clicked"),
                    ),
                    const SizedBox(width: 10),
                    _Iteractionbox(
                      image: "assets/money.png",
                      number: "11",
                      label: "Fee",
                      onTap: () => print("Fee clicked"),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              // Other
              Row(
                children: const [
                  Text(
                    'Other',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Iteractionbox(
                    image: "assets/group.png",
                    number: "3",
                    label: "Groups",
                    onTap: () => print("Groups clicked"),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              // For You
              Row(
                children: const [
                  Text(
                    'For you',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ColoredLinkBox(
                      url: "https://github.com/",
                      assetImage: "assets/github.png",
                      label: "GitHub",
                      color: Colors.black,
                      context: context,
                    ),
                    const SizedBox(width: 10),
                    _ColoredLinkBox(
                      url: "https://stackoverflow.com/",
                      assetImage: "assets/overflow.png",
                      label: "StackOverflow",
                      color: Colors.orange,
                      context: context,
                    ),
                    const SizedBox(width: 10),
                    _ColoredLinkBox(
                      url: "https://www.freecodecamp.org/",
                      assetImage: "assets/fcc.png",
                      label: "FreeCodeCamp",
                      color: Colors.green,
                      context: context,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Clickable Iteraction Box
Widget _Iteractionbox({
  required String image,
  required String number,
  required String label,
  VoidCallback? onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(10),
      width: 90,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(number, style: const TextStyle(color: Colors.black)),
              Image.asset(image, width: 25, height: 25),
            ],
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

// Colored Link Box using context
Widget _ColoredLinkBox({
  required String url,
  required String assetImage,
  required String label,
  required Color color,
  required BuildContext context,
}) {
  return GestureDetector(
    onTap: () async {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the link')),
        );
      }
    },
    child: Container(
      padding: const EdgeInsets.all(10),
      width: 110,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 5)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ColorFiltered(
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            child: Image.asset(
              assetImage,
              width: 35,
              height: 35,
              errorBuilder:
                  (context, error, stackTrace) =>
                      Icon(Icons.link, size: 35, color: color),
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

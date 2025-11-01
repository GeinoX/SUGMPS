import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sugmps/routes.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  _HomepageState createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  File? profileImage;
  final ImagePicker picker = ImagePicker();

  String? name;
  String? program;
  String? profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadStudentInfo();
  }

  Future<void> _loadStudentInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    // Load locally if available
    String? localName = prefs.getString('student_name');
    String? localProgram = prefs.getString('student_program');
    String? localImage = prefs.getString('student_image');

    setState(() {
      name = localName ?? name;
      program = localProgram ?? program;
      profileImagePath = localImage ?? profileImagePath;
    });

    // Fetch from backend
    try {
      final response = await http.get(
        Uri.parse('https://e708f1bfee58.ngrok-free.app/umsapp/stud_info/'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];

        String? imageUrl = data['image']?.toString().trim(); // trim spaces

        setState(() {
          name = data['name'];
          program = data['program'];
          profileImagePath = imageUrl;
        });

        // Save locally
        prefs.setString('student_name', name!);
        prefs.setString('student_program', program!);
        if (imageUrl != null && imageUrl.isNotEmpty) {
          prefs.setString('student_image', imageUrl);
        }
      } else {
        print('Failed to fetch student info. Status: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching student info: $e");
    }
  }

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
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromRGBO(255, 255, 255, 0.95),
      ),
      backgroundColor: const Color.fromRGBO(255, 255, 255, 0.95),
      body: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Profile Container
              // Profile Container
              Container(
                padding: EdgeInsets.all(screenWidth * 0.04),
                height: screenHeight * 0.22,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF3C3889),
                  borderRadius: BorderRadius.circular(screenWidth * 0.04),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Profile Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Profile Image
                        ClipOval(
                          child:
                              profileImagePath != null
                                  ? CachedNetworkImage(
                                    imageUrl: profileImagePath!.trim(),
                                    width: screenWidth * 0.16,
                                    height: screenWidth * 0.16,
                                    fit: BoxFit.cover,
                                    placeholder:
                                        (context, url) => Container(
                                          width: screenWidth * 0.16,
                                          height: screenWidth * 0.16,
                                          color: Colors.grey.shade300,
                                          child: Icon(
                                            Icons.person,
                                            size: screenWidth * 0.06,
                                          ),
                                        ),
                                    errorWidget:
                                        (context, url, error) => Container(
                                          width: screenWidth * 0.16,
                                          height: screenWidth * 0.16,
                                          color: Colors.grey.shade300,
                                          child: Icon(
                                            Icons.person,
                                            size: screenWidth * 0.06,
                                          ),
                                        ),
                                  )
                                  : Container(
                                    width: screenWidth * 0.16,
                                    height: screenWidth * 0.16,
                                    color: Colors.grey.shade300,
                                    child: Icon(
                                      Icons.person,
                                      size: screenWidth * 0.06,
                                    ),
                                  ),
                        ),
                        // Name & Program
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name ?? 'Loading...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: screenWidth * 0.04,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.005),
                            Text(
                              program ?? 'Loading...',
                              style: TextStyle(
                                color: const Color(0xFFE77B22),
                                fontSize: screenWidth * 0.03,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Progress Row

                    // Attendance
                    Column(
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Attendance',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              '59%',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            height: 5,
                            width: 400,
                            child: LinearProgressIndicator(
                              value: 0.59,
                              backgroundColor: Colors.white,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(15),
                              ),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFE77B22),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Fee
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.03),
              _SectionTitle(label: 'School Updates', screenWidth: screenWidth),
              SizedBox(height: screenHeight * 0.01),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Iteractionbox(
                    image: "assets/newspaper.png",
                    number: "3",
                    label: "News",
                    onTap: () => print("News clicked"),
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                  ),
                  _Iteractionbox(
                    image: "assets/calendar.png",
                    number: "5",
                    label: "Events",
                    onTap: () => print("Events clicked"),
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                  ),
                  _Iteractionbox(
                    image: "assets/megaphone.png",
                    number: "11",
                    label: "Bulletin",
                    onTap:
                        () => Navigator.popAndPushNamed(
                          context,
                          AppRoutes.notifications,
                        ),
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                  ),
                ],
              ),

              SizedBox(height: screenHeight * 0.025),
              _SectionTitle(label: 'Academics', screenWidth: screenWidth),
              SizedBox(height: screenHeight * 0.01),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Iteractionbox(
                    image: "assets/assignment.png",
                    number: "3",
                    label: "Timetable",
                    onTap:
                        () => Navigator.pushNamed(
                          context,
                          AppRoutes.timetablepage,
                        ),
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  _Iteractionbox(
                    image: "assets/certificate.png",
                    number: "6",
                    label: "Courses",
                    onTap:
                        () => Navigator.popAndPushNamed(
                          context,
                          AppRoutes.coursepage,
                        ),
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  _Iteractionbox(
                    image: "assets/immigration.png",
                    number: "2",
                    label: "Attendance",
                    onTap:
                        () => Navigator.popAndPushNamed(
                          context,
                          AppRoutes.coursedisplay,
                        ),
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                  ),
                ],
              ),

              SizedBox(height: screenHeight * 0.025),
              _SectionTitle(label: 'Other', screenWidth: screenWidth),
              SizedBox(height: screenHeight * 0.01),
              Row(
                children: [
                  _Iteractionbox(
                    image: "assets/group.png",
                    number: "3",
                    label: "Groups",
                    onTap: () => print("Groups clicked"),
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                  ),
                ],
              ),

              SizedBox(height: screenHeight * 0.025),
              _SectionTitle(label: 'For You', screenWidth: screenWidth),
              SizedBox(height: screenHeight * 0.01),
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
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    _ColoredLinkBox(
                      url: "https://stackoverflow.com/",
                      assetImage: "assets/overflow.png",
                      label: "StackOverflow",
                      color: Colors.orange,
                      context: context,
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    _ColoredLinkBox(
                      url: "https://www.freecodecamp.org/",
                      assetImage: "assets/fcc.png",
                      label: "FreeCodeCamp",
                      color: Colors.green,
                      context: context,
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
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

// -------------------- WIDGETS --------------------

Widget _SectionTitle({required String label, required double screenWidth}) {
  return Align(
    alignment: Alignment.centerLeft,
    child: Text(
      label,
      style: TextStyle(
        fontSize: screenWidth * 0.04,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

Widget _ProgressIndicator({
  required String label,
  required double value,
  required double screenWidth,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: screenWidth * 0.035,
            ),
          ),
          SizedBox(width: screenWidth * 0.02),
          Text(
            '${(value * 100).toInt()}%',
            style: TextStyle(
              color: Colors.white,
              fontSize: screenWidth * 0.035,
            ),
          ),
        ],
      ),
      SizedBox(height: screenWidth * 0.02),
      SizedBox(
        height: screenWidth * 0.02,
        width: screenWidth * 0.95,
        child: LinearProgressIndicator(
          value: value,
          backgroundColor: Colors.white,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE77B22)),
          borderRadius: BorderRadius.circular(screenWidth * 0.02),
        ),
      ),
    ],
  );
}

Widget _Iteractionbox({
  required String image,
  required String number,
  required String label,
  VoidCallback? onTap,
  required double screenWidth,
  required double screenHeight,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.all(screenWidth * 0.02),
      width: screenWidth * 0.25,
      height: screenHeight * 0.11,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(screenWidth * 0.02),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                number,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: screenWidth * 0.035,
                ),
              ),
              Image.asset(
                image,
                width: screenWidth * 0.07,
                height: screenWidth * 0.07,
              ),
            ],
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _ColoredLinkBox({
  required String url,
  required String assetImage,
  required String label,
  required Color color,
  required BuildContext context,
  required double screenWidth,
  required double screenHeight,
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
      padding: EdgeInsets.all(screenWidth * 0.02),
      width: screenWidth * 0.28,
      height: screenHeight * 0.1,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(screenWidth * 0.02),
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 5)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ColorFiltered(
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            child: Image.asset(
              assetImage,
              width: screenWidth * 0.09,
              height: screenWidth * 0.09,
              errorBuilder:
                  (context, error, stackTrace) =>
                      Icon(Icons.link, size: screenWidth * 0.09, color: color),
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}

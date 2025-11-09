import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'styles.dart';
import 'package:sugmps/core/routes/routes.dart';

class OS1 extends StatefulWidget {
  const OS1({super.key});

  @override
  State<OS1> createState() => _OS1State();
}

class _OS1State extends State<OS1> {
  final PageController _pageController = PageController();
  int _pageIndex = 0; // track current page
  bool _imagesPrecached = false;
  bool _showOnboarding = true; // controls whether to show onboarding

  final List<Map<String, String>> _pages = [
    {'image': AppImages.image1, 'title': AppText.title1, 'text': AppText.text1},
    {'image': AppImages.image2, 'title': AppText.title2, 'text': AppText.text2},
    {'image': AppImages.image3, 'title': AppText.title3, 'text': AppText.text3},
    {'image': AppImages.image4, 'title': AppText.title4, 'text': AppText.text4},
    {'image': AppImages.image5, 'title': AppText.title5, 'text': AppText.text5},
    {'image': AppImages.image6, 'title': AppText.title6, 'text': AppText.text6},
  ];



  void _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);

    // Navigate to the next screen
    Navigator.pushReplacementNamed(context, AppRoutes.usertype);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_imagesPrecached) {
      for (var page in _pages) {
        precacheImage(AssetImage(page['image']!), context);
      }
      _imagesPrecached = true;
    }
  }

  void _nextPage() {
    if (_pageIndex < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  Widget _dot(int index) {
    return Container(
      width: _pageIndex == index ? 12 : 8,
      height: _pageIndex == index ? 12 : 8,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _pageIndex == index ? Colors.blue : Colors.grey.shade400,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _pageIndex = i),
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                final page = _pages[index];
                return _OS_Super(
                  image: page['image']!,
                  title: page['title']!,
                  text: page['text']!,
                );
              },
            ),
          ),
          // Dots + Next button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [for (int i = 0; i < _pages.length; i++) _dot(i)],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _pageIndex < _pages.length - 1 ? "Next" : "Get Started",
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _OS_Super({
  required String image,
  required String title,
  required String text,
}) {
  return Padding(
    padding: const EdgeInsets.all(AppSizing.edgeinsets),
    child: Column(
      children: [
        const SizedBox(height: AppSizing.fsb),
        Image.asset(image, height: 350, width: 300),
        const SizedBox(height: AppSizing.ssb),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 19,
          ),
        ),
        const SizedBox(height: AppSizing.tsb),
        Text(
          text,
          style: TextStyle(
            color: AppColors.whiteWithOpacity60,
            fontWeight: FontWeight.normal,
            fontSize: AppSizing.textfont,
          ),
        ),
      ],
    ),
  );
}

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
  int _pageIndex = 0;
  bool _imagesPrecached = false;

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
    Navigator.pushReplacementNamed(context, AppRoutes.login);
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

  void _skipOnboarding() {
    _completeOnboarding();
  }

  Widget _dot(int index) {
    return Container(
      width: _pageIndex == index ? 16 : 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(4),
        color: _pageIndex == index ? AppColors.primary : Colors.grey.shade300,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button (only show if not on last page)
            if (_pageIndex < _pages.length - 1)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.all(AppSizing.getEdgeInsets(context)),
                  child: TextButton(
                    onPressed: _skipOnboarding,
                    child: Text(
                      "Skip",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: AppSizing.getTextFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _pageIndex = i),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _OnboardingPage(
                    image: page['image']!,
                    title: page['title']!,
                    text: page['text']!,
                  );
                },
              ),
            ),

            // Bottom section with dots and button
            Container(
              padding: EdgeInsets.all(AppSizing.getEdgeInsets(context)),
              child: Column(
                children: [
                  // Dots indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [for (int i = 0; i < _pages.length; i++) _dot(i)],
                  ),

                  SizedBox(height: AppSizing.getSpacing(context, 3)),

                  // Next/Get Started button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: AppSizing.getSpacing(context, 2),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        _pageIndex < _pages.length - 1 ? "Next" : "Get Started",
                        style: TextStyle(
                          fontSize: AppSizing.getButtonFontSize(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final String image;
  final String title;
  final String text;

  const _OnboardingPage({
    required this.image,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppSizing.getEdgeInsets(context)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image
          Image.asset(
            image,
            height: AppSizing.getImageHeight(context),
            width: AppSizing.getImageWidth(context),
            fit: BoxFit.contain,
          ),

          SizedBox(height: AppSizing.getSpacing(context, 4)),

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: AppSizing.getTitleFontSize(context),
            ),
          ),

          SizedBox(height: AppSizing.getSpacing(context, 2)),

          // Description
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.normal,
              fontSize: AppSizing.getTextFontSize(context),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

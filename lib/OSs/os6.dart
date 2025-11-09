import 'package:flutter/material.dart';
import 'package:sugmps/core/routes/routes.dart';
import 'styles.dart';

class OS6 extends StatefulWidget {
  const OS6({super.key});

  @override
  State<OS6> createState() => _OS6State();
}

class _OS6State extends State<OS6> {
  bool _imagesPrecached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesPrecached) {
      precacheImage(const AssetImage(AppImages.image6), context);
      _imagesPrecached = true;
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSizing.getEdgeInsets(context)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Image
              Image.asset(
                AppImages.image6,
                height: AppSizing.getImageHeight(context),
                width: AppSizing.getImageWidth(context),
                fit: BoxFit.contain,
              ),

              SizedBox(height: AppSizing.getSpacing(context, 4)),

              // Title
              Text(
                AppText.title6,
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
                AppText.text6,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.normal,
                  fontSize: AppSizing.getTextFontSize(context),
                  height: 1.5,
                ),
              ),

              SizedBox(height: AppSizing.getSpacing(context, 6)),

              // Get Started button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _navigateToLogin,
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
                    "Get Started",
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
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:acafe_customer/common/widgets/custom_app_bar_widget.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ProductImageScreen extends StatefulWidget {
  final String? image;
  final String? title;
  const ProductImageScreen({super.key, this.image, this.title});

  @override
  State<ProductImageScreen> createState() => _ProductImageScreenState();
}

class _ProductImageScreenState extends State<ProductImageScreen> {
  int? pageIndex;
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
    //NetworkInfo.checkConnectivity(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: widget.title, context: context,),
      body: Center(
        child: SizedBox(
          width: 1170,
          child: Column(children: [
            Expanded(
              child: Stack(
                children: [
                  PhotoViewGallery.builder(
                    scrollPhysics: const BouncingScrollPhysics(),
                    builder: (BuildContext context, int index) {
                      return PhotoViewGalleryPageOptions(
                        imageProvider: NetworkImage(
                          kIsWeb ? CustomImageWidget.resolveWebImageUrl(widget.image ?? '') : widget.image ?? '',
                        ),
                        initialScale: PhotoViewComputedScale.contained,
                      );
                    },
                    backgroundDecoration: BoxDecoration(color: Theme.of(context).cardColor),
                    itemCount: 1,
                    loadingBuilder: (context, event) => Center(
                      child: SizedBox(
                        width: 20.0,
                        height: 20.0,
                        child: CircularProgressIndicator(
                          value: event == null ? 0 : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
                          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                        ),
                      ),
                    ),
                    pageController: _pageController,
                    onPageChanged: (int index) {
                      setState(() {
                        pageIndex = index;
                      });
                    },
                  ),

                  // pageIndex != 0 ? Positioned(
                  //   left: 5, top: 0, bottom: 0,
                  //   child: Container(
                  //     alignment: Alignment.center,
                  //     decoration: const BoxDecoration(
                  //       color: Colors.grey,
                  //       shape: BoxShape.circle,
                  //     ),
                  //     child: InkWell(
                  //       onTap: () {
                  //         if(pageIndex! > 0) {
                  //           _pageController!.animateToPage(pageIndex!-1, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                  //         }
                  //       },
                  //       child: const Icon(Icons.chevron_left_outlined, size: 40),
                  //     ),
                  //   ),
                  // ) : const SizedBox.shrink(),

                ],
              ),
            ),

          ]),
        ),
      ),
    );
  }
}


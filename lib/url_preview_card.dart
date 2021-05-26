library url_preview_card;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_preview_card/widgets/preview_description.dart';
import 'package:url_preview_card/widgets/preview_image.dart';
import 'package:url_preview_card/widgets/preview_site_name.dart';
import 'package:url_preview_card/widgets/preview_title.dart';
import 'package:string_validator/string_validator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Provides URL preview
class UrlPreviewCard extends StatefulWidget {
  /// URL for which preview is to be shown
  final String url;

  /// Height of the preview
  final double previewHeight;

  /// Text style for title
  final TextStyle titleStyle;

  /// Text style for description
  final TextStyle descriptionStyle;

  // Text style for site name
  final TextStyle siteNameStyle;

  /// Background color
  final Color bgColor;

  /// Number of lines for Title. (Max possible lines = 2)
  final int titleLines;

  /// Number of lines for Description. (Max possible lines = 3)
  final int descriptionLines;

  /// Color for loader icon shown, till image loads
  final Color imageLoaderColor;

  /// Container padding
  final EdgeInsetsGeometry previewContainerPadding;

  /// onTap URL preview, by default opens URL in default browser
  final VoidCallback onTap;

  UrlPreviewCard({
    @required this.url,
    this.previewHeight = 130.0,
    this.titleStyle = const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 16,
      color: Colors.black,
    ),
    this.descriptionStyle = const TextStyle(
      fontSize: 14,
      color: Colors.black,
    ),
    this.siteNameStyle = const TextStyle(
      fontSize: 14,
      color: Colors.black,
    ),
    this.bgColor = Colors.white,
    this.titleLines = 2,
    this.descriptionLines = 3,
    this.imageLoaderColor,
    this.previewContainerPadding,
    this.onTap,
  });

  @override
  _UrlPreviewCardState createState() => _UrlPreviewCardState();
}

class _UrlPreviewCardState extends State<UrlPreviewCard> {
  Map _urlPreviewData;
  bool _isVisible = true;
  TextStyle _titleStyle;
  TextStyle _descriptionStyle;
  TextStyle _siteNameStyle;
  double _previewHeight;
  Color _bgColor;
  int _titleLines;
  int _descriptionLines;
  Color _imageLoaderColor;
  EdgeInsetsGeometry _previewContainerPadding;
  VoidCallback _onTap;

  @override
  void initState() {
    super.initState();
    _getUrlData();
  }

  @override
  void didUpdateWidget(UrlPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _getUrlData();
  }

  void _initialize() {
    _previewHeight = widget.previewHeight;
    _descriptionLines = widget.descriptionLines;
    _titleLines = widget.titleLines;
    _previewContainerPadding = widget.previewContainerPadding;
    _onTap = widget.onTap ?? _launchURL;
    _titleStyle = widget.titleStyle;
    _descriptionStyle = widget.descriptionStyle;
    _siteNameStyle = widget.siteNameStyle;
  }

  void _getUrlData() async {
    final _pref = await SharedPreferences.getInstance();

    if (!this.mounted) return;

    if (!isURL(widget.url)) {
      setState(() {
        _urlPreviewData = null;
      });
      return;
    }

    final cachedData = _pref.getString(widget.url);
    if (cachedData != null) {
      setState(() {
        _urlPreviewData = jsonDecode(cachedData);
        _isVisible = true;
      });
    }

    var response = await get(Uri.parse(widget.url));
    if (!this.mounted) return;

    if (response.statusCode != 200) {
      setState(() {
        _urlPreviewData = null;
      });
    }

    var document = parse(response.body);
    Map data = {};
    _extractOGData(document, data, 'og:title');
    _extractOGData(document, data, 'og:description');
    _extractOGData(document, data, 'og:site_name');
    _extractOGData(document, data, 'og:image');

    if (data != null && data.isNotEmpty) {
      _pref.setString(widget.url, jsonEncode(data));
      setState(() {
        _urlPreviewData = data;
        _isVisible = true;
      });
    }
  }

  void _extractOGData(Document document, Map data, String parameter) {
    final metaTags = document.getElementsByTagName("meta");

    if (metaTags == null) return;

    // we search for og tag regardless of the attribute name
    final metaTag = metaTags.firstWhere(
      (element) => element.attributes.containsValue(parameter),
      orElse: () => null,
    );

    if (metaTag == null) return;

    data[parameter] = metaTag.attributes['content'];
  }

  void _launchURL() async {
    if (await canLaunch(Uri.encodeFull(widget.url))) {
      await launch(Uri.encodeFull(widget.url));
    } else {
      throw 'Could not launch ${widget.url}';
    }
  }

  @override
  Widget build(BuildContext context) {
    _bgColor = widget.bgColor ?? Theme.of(context).primaryColor;
    _imageLoaderColor =
        widget.imageLoaderColor ?? Theme.of(context).accentColor;
    _initialize();

    if (_urlPreviewData == null || !_isVisible) {
      return SizedBox();
    }

    return Container(
      padding: _previewContainerPadding,
      height: _previewHeight,
      child: GestureDetector(
        onTap: _onTap,
        child: _buildPreviewCard(context),
      ),
    );
  }

  Card _buildPreviewCard(BuildContext context) {
    return Card(
      elevation: 5,
      margin: const EdgeInsets.all(0.0),
      color: _bgColor,
      child: Row(
        children: [
          ClipRRect(
            child: Container(
              width: widget.previewHeight,
              height: widget.previewHeight,
              child: PreviewImage(
                _urlPreviewData['og:image'],
                _imageLoaderColor,
              ),
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(4.0),
              bottomLeft: Radius.circular(4.0),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  PreviewTitle(
                    _urlPreviewData['og:title'],
                    _titleStyle,
                    _titleLines,
                  ),
                  Expanded(
                    child: PreviewDescription(
                      _urlPreviewData['og:description'],
                      _descriptionStyle,
                      _descriptionLines,
                    ),
                  ),
                  PreviewSiteName(
                    _urlPreviewData['og:site_name'],
                    _siteNameStyle,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

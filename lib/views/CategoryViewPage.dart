import 'package:auto_size_text/auto_size_text.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';

import 'package:piwigo_ng/api/API.dart';
import 'package:piwigo_ng/api/CategoryAPI.dart';
import 'package:piwigo_ng/api/ImageAPI.dart';
import 'package:piwigo_ng/constants/SettingsConstants.dart';
import 'package:piwigo_ng/services/OrientationService.dart';
import 'package:piwigo_ng/services/UploadStatusProvider.dart';
import 'package:piwigo_ng/views/components/list_item.dart';
import 'package:piwigo_ng/views/components/snackbars.dart';

import 'package:piwigo_ng/views/ImageViewPage.dart';
import 'package:piwigo_ng/views/UploadGalleryViewPage.dart';
import 'package:piwigo_ng/views/components/dialogs/dialogs.dart';
import 'package:provider/provider.dart';


class CategoryViewPage extends StatefulWidget {
  CategoryViewPage({Key key, this.title, this.category, this.isAdmin, this.nbImages}) : super(key: key);
  final bool isAdmin;
  final String title;
  final String category;
  final int nbImages;

  @override
  _CategoryViewPageState createState() => _CategoryViewPageState();
}
class _CategoryViewPageState extends State<CategoryViewPage> with SingleTickerProviderStateMixin {
  Future<Map<String,dynamic>> _albumsFuture;
  Future<Map<String,dynamic>> _imagesFuture;

  bool _canUpload = false;
  bool _isEditMode;
  int _page;
  int _nbImages;
  Map<int, dynamic> _selectedItems = Map();
  List<dynamic> imageList = [];


  @override
  void initState() {
    _getData();
    super.initState();
    _page = 0;
    _nbImages = widget.nbImages;
    _isEditMode = false;
  }

  void _getData() {
    _albumsFuture = fetchAlbums(widget.category);
    _imagesFuture = fetchImages(widget.category, 0);
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool _isSelected(int id) {
    return _selectedItems.keys.contains(id);
  }

  Future<void> showMore() async {
    _page++;
    var response = await fetchImages(widget.category, _page);
    if(response['stat'] == 'fail') {
      ScaffoldMessenger.of(context).showSnackBar(
          errorSnackBar(context, response['result'])
      );
    } else {
      var newListPage = response['result']['images'];
      imageList.addAll(newListPage);
    }
    setState(() {
      _getData();
    });
  }
  void openEditMode() {
    setState(() {
      _isEditMode = true;
    });
  }
  void closeEditMode() {
    setState(() {
      _isEditMode = false;
    });
    _selectedItems.clear();
  }

  Future<void> _onRefresh() async {
    setState(() {
      _page = 0;
      _getData();
    });
    return Future.delayed(Duration(milliseconds: 500));
  }

  Future<void> _onEditSelection() async {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EditImagesPage(
          catId: int.parse(widget.category),
          images: _selectedItems.values.toList(),
        ))
    );
  }
  Future<void> _onDownloadSelection() async {
    final int option = await confirmDownloadDialog(context,
      nbImages: _selectedItems.length,
    );
    if(option == -1) return;

    List<dynamic> selection = [];
    selection.addAll(_selectedItems.values.toList());

    switch (option) {
      case 0: share(selection);
        break;
      case 1: downloadImages(selection);
        break;
    }

    setState(() {
      _isEditMode = false;
      _selectedItems.clear();
    });
  }
  Future<void> _onMoveCopySelection() async {
    int choice = await chooseMoveCopyImage(context,
      content: appStrings(context).moveOrCopyImage_title(_selectedItems.length)
    );

    switch(choice) {
      case 0: showDialog(context: context,
          builder: (context) {
            return MoveOrCopyDialog(
              title: appStrings(context).moveImage_title,
              subtitle: appStrings(context).moveImage_selectAlbum(_selectedItems.length, ''),
              catId: widget.category,
              catName: widget.title,
              isImage: true,
              onSelected: (item) async {
                if( await confirmMoveDialog(context,
                  content: appStrings(context).moveImage_message(_selectedItems.length, "", item.name),
                )) {
                  int nbMoved = await moveImages(context,
                      _selectedItems.values.toList(),
                      int.parse(item.id)
                  );
                  ScaffoldMessenger.of(context).showSnackBar(imagesMovedSnackBar(context, nbMoved));
                  Navigator.of(context).pop();
                }
              },
            );
          }
        ).whenComplete(() {
          setState(() {
            _selectedItems.clear();
            _isEditMode = false;
            _getData();
          });
        });
        break;
      case 1: showDialog(context: context,
          builder: (context) {
            return MoveOrCopyDialog(
              title: appStrings(context).copyImage_title,
              subtitle: appStrings(context).copyImage_selectAlbum(_selectedItems.length, ''),
              catId: widget.category,
              catName: widget.title,
              isImage: true,
              onSelected: (item) async {
                if( await confirmAssignDialog(context,
                  content: appStrings(context).copyImage_message(_selectedItems.length, "", item.name),
                )) {
                  int nbCopied = await assignImages(context,
                      _selectedItems.values.toList(),
                      int.parse(item.id)
                  );
                  ScaffoldMessenger.of(context).showSnackBar(imagesAssignedSnackBar(context, nbCopied));
                  Navigator.of(context).pop();
                }
              },
            );
          }
        ).whenComplete(() {
          setState(() {
            _selectedItems.clear();
            _isEditMode = false;
            _getData();
          });
        });
        break;
      default: break;
    }
  }
  Future<void> _onDeleteSelection() async {
    int choice = await confirmRemoveImagesFromAlbumDialog(context,
      content: appStrings(context).deleteImage_message(_selectedItems.length),
      count: _selectedItems.length,
    );
    if(choice != -1) {
      List<int> selection = [];
      selection.addAll(_selectedItems.keys.toList());

      setState(() {
        _isEditMode = false;
        _selectedItems.clear();
      });

      int nbSuccess = 0;
      switch(choice) {
        case 0: nbSuccess = await deleteImages(context, selection);
          break;
        case 1: nbSuccess = await removeImages(context, selection, widget.category);
          break;
        default: break;
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(appStrings(context).deleteImageSuccess_message(nbSuccess)),
      ));

      setState(() {
        _getData();
      });
    }
  }

  void _onSelectAll() {
    setState(() {
      if(_selectedItems.length == imageList.length) {
        _selectedItems.clear();
      } else {
        imageList.forEach((image) {
          _selectedItems.putIfAbsent(image['id'], () => image);
        });
      }
    });
  }
  void _onSelectDeselect(Map<String, dynamic> image) {
    if(_isSelected(image['id'])) {
      _selectedItems.remove(image['id']);
      if(_selectedItems.isEmpty) {
        _isEditMode = false;
      }
    } else {
      _selectedItems.putIfAbsent(image['id'], () => image);
    }
  }
  void _onLongPressImage(Map<String, dynamic> image) {
    if(_isEditMode) {
      setState(() {
        _onSelectDeselect(image);
      });
    } else if(widget.isAdmin) {
      setState(() {
        _isEditMode = true;
        _selectedItems.putIfAbsent(image['id'], () => image);
      });
    }
  }
  void _onTapImage(Map<String, dynamic> image, int index) {
    if(_isEditMode) {
      setState(() {
        _onSelectDeselect(image);
      });
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) =>
            ImageViewPage(
              images: imageList,
              index: index,
              isAdmin: widget.isAdmin,
              category: widget.category,
            )),
      ).whenComplete(() {
        setState(() {
          _getData();
        });
      });
    }
  }

  Future<bool> _onBack() async {
    if(_isEditMode) {
      closeEditMode();
      return false;
    }
    return true;
  }

  handleAlbumSnapshot(AsyncSnapshot albumSnapshot, int nbImages) {
    var albums = albumSnapshot.data['result']['categories'];
    if(albums.length > 0 && albums.first["id"].toString() == widget.category) {
      _nbImages = albums.first["total_nb_images"];
      _canUpload = albums.first["can_upload"] ?? false;
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        setState(() {});
      });
    }
    albums.removeWhere((category) =>
      (category["id"].toString() == widget.category)
    );
    return albums;
  }
  handleImagesSnapshot(AsyncSnapshot imagesSnapshot) {
    imageList.clear();
    imageList.addAll(imagesSnapshot.data['result']['images']);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBack,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        extendBody: true,
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          child: CustomScrollView(
            slivers: [
              _createAppBar,
              SliverToBoxAdapter(child: _createFutureBuilders,),
            ],
          ),
        ),
        floatingActionButton: _isEditMode
            ? const SizedBox()
            : _createFloatingActionButton,
        bottomNavigationBar: _isEditMode
            ? _createBottomBar
            : const SizedBox(),
      ),
    );
  }

  Widget get _createAppBar {
    ThemeData _theme = Theme.of(context);
    return SliverAppBar(
      pinned: true,
      centerTitle: true,
      iconTheme: IconThemeData(
        color: _theme.iconTheme.color,
      ),
      leading: IconButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        icon: Icon(Icons.chevron_left),
      ),
      title: _isEditMode ?
      Text("${_selectedItems.length}", overflow: TextOverflow.fade, softWrap: true) :
      Text(widget.title),
      actions: widget.isAdmin ? [
        _isEditMode ? IconButton(
          onPressed: _onSelectAll,
          icon: _selectedItems.length == imageList.length ?
            Icon(Icons.check_circle) : Icon(Icons.circle_outlined),
        ) : SizedBox(),
        _isEditMode ? IconButton(
          onPressed: closeEditMode,
          icon: Icon(Icons.cancel),
        ) : widget.isAdmin ? IconButton(
          onPressed: openEditMode,
          icon: Icon(Icons.touch_app_rounded),
        ) : SizedBox(),
      ] : [],
    );
  }

  Widget get _createFutureBuilders {
    return FutureBuilder<Map<String,dynamic>>(
        future: _albumsFuture, // Albums of the list
        builder: (BuildContext context, AsyncSnapshot albumSnapshot) {
          if (albumSnapshot.hasData) {
            int nbImages = _nbImages;
            if(albumSnapshot.data['stat'] == 'fail') {
              return Center(
                child: Text(appStrings(context).categoryImageList_noDataError),
              );
            }
            var albums = handleAlbumSnapshot(albumSnapshot, nbImages);
            return FutureBuilder<Map<String,dynamic>>(
              future: _imagesFuture,
              builder: (BuildContext context, AsyncSnapshot imagesSnapshot) {
                if (imagesSnapshot.hasData) {
                  if (imageList.isEmpty || _page == 0) {
                    if(imagesSnapshot.data['stat'] == 'fail') {
                      return Center(child: Text(appStrings(context).categoryImageList_noDataError));
                    }
                    handleImagesSnapshot(imagesSnapshot);
                  }
                  return _createPageContent(albums, nbImages);
                }
                return Center(child: CircularProgressIndicator());
              },
            );
          }
          return Center(child: CircularProgressIndicator());
        }
    );
  }

  Widget get _createUploadActionButton {
    ThemeData _theme = Theme.of(context);
    return SpeedDial(
      spaceBetweenChildren: 10,
      childMargin: EdgeInsets.only(bottom: 17, right: 10),
      animatedIcon: AnimatedIcons.menu_close,
      animatedIconTheme: IconThemeData(size: 22.0),
      closeManually: false,
      curve: Curves.bounceIn,
      backgroundColor: _theme.floatingActionButtonTheme.backgroundColor,
      foregroundColor: _theme.floatingActionButtonTheme.foregroundColor,
      overlayColor: Colors.black,
      elevation: 5.0,
      overlayOpacity: 0.5,
      shape: CircleBorder(),
      children: [
        if(widget.isAdmin)
          SpeedDialChild(
          elevation: 5,
          labelWidget: Text(appStrings(context).createNewAlbum_title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          child: Icon(Icons.create_new_folder),
          backgroundColor: _theme.floatingActionButtonTheme.backgroundColor,
          foregroundColor: _theme.floatingActionButtonTheme.foregroundColor,
          onTap: () async {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return CreateCategoryDialog(catId: widget.category);
              }
            ).whenComplete(() {
              setState(() {
                _getData();
              });
            });
          },
        ),
        if(_canUpload) ... [
          SpeedDialChild(
              elevation: 5,
              labelWidget: Text(appStrings(context).categoryUpload_images, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              child: Icon(Icons.add_to_photos),
              backgroundColor: _theme.floatingActionButtonTheme.backgroundColor,
              foregroundColor: _theme.floatingActionButtonTheme.foregroundColor,
              onTap: () async {
                try {
                  ScaffoldMessenger.of(context).removeCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(appStrings(context).loadingHUD_label),
                        CircularProgressIndicator(),
                      ],
                    ),
                    duration: Duration(days: 365),
                  ));
                  final List<XFile> images = ((await FilePicker.platform.pickFiles(
                    type: FileType.media,
                    allowMultiple: true,
                  )) ?.files ?? []).map<XFile>((e) => XFile(e.path, name: e.name, bytes: e.bytes)).toList();
                  ScaffoldMessenger.of(context).removeCurrentSnackBar();
                  if(images.isNotEmpty) {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (context) => UploadGalleryViewPage(imageData: images, category: widget.category)
                    )).whenComplete(() {
                      setState(() {});
                    });
                  }
                } catch (e) {
                  debugPrint('${e.toString()}');
                }
              }
          ),
          SpeedDialChild(
              elevation: 5,
              labelWidget: Text(appStrings(context).categoryUpload_take, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              child: Icon(Icons.photo_camera_rounded),
              backgroundColor: _theme.floatingActionButtonTheme.backgroundColor,
              foregroundColor: _theme.floatingActionButtonTheme.foregroundColor,
              onTap: () async {
                try {
                  ScaffoldMessenger.of(context).removeCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(appStrings(context).loadingHUD_label),
                        CircularProgressIndicator(),
                      ],
                    ),
                    duration: Duration(days: 365),
                  ));
                  final XFile image = await ImagePicker().pickImage(source: ImageSource.camera);
                  ScaffoldMessenger.of(context).removeCurrentSnackBar();
                  if(image != null) {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (context) => UploadGalleryViewPage(imageData: [image], category: widget.category)
                    )).whenComplete(() {
                      setState(() {});
                    });
                  }
                } catch (e) {
                  debugPrint('Dio error ${e.toString()}');
                }
              }
          ),
        ],
      ],
    );
  }

  Widget _createPageContent(dynamic albums, int nbImages) {
    ThemeData _theme = Theme.of(context);

    int albumCrossAxisCount = MediaQuery.of(context).size.width <= Constants.albumMinWidth ? 1
        : (MediaQuery.of(context).size.width/Constants.albumMinWidth).round();

    return Column(
      children: [
        albums.length > 0 ?
        GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: albumCrossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: albumGridAspectRatio(context),
          ),
          padding: EdgeInsets.all(10),
          itemCount: albums.length,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemBuilder: (BuildContext context, int index) {
            var album = albums[index];
            print(widget.isAdmin);
            return AlbumListItem(album,
              isAdmin: widget.isAdmin && API.prefs.getString('user_status') != 'normal',
              canUpload: API.prefs.getString('user_status') == 'normal' && _canUpload,
              onClose: () {
                setState(() {
                  _getData();
                });
              },
              onOpen: closeEditMode,
            );
          },
        ) : Center(),
        imageList.length > 0 ?
        GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: getImageCrossAxisCount(context),
            mainAxisSpacing: 3.0,
            crossAxisSpacing: 3.0,
          ),
          padding: EdgeInsets.symmetric(horizontal: 5),
          itemCount: imageList.length,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemBuilder: (BuildContext context, int index) {
            var image = imageList[index];
            bool selected = _isSelected(image['id']);
            return InkWell(
              onLongPress: () => _onLongPressImage(image),
              onTap: () => _onTapImage(image, index),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    width: selected ? 5 : 0,
                    color: selected ? _theme.colorScheme.primary : Colors.transparent,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      child: Image.network(
                        imageList[index]["derivatives"][API.prefs.getString('thumbnail_size')]["url"],
                        fit: BoxFit.cover,
                      ),
                    ),
                    selected ? Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Color(0x80000000),
                    ) : const SizedBox(),
                    API.prefs.getBool('show_thumbnail_title')? Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        color: Color(0x80ffffff),
                        child: AutoSizeText('${image['name']}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(fontSize: 12),
                          maxFontSize: 14, minFontSize: 7,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ) : const SizedBox(),
                  ],
                ),
              ),
            );
          },
        ) : Center(),
        nbImages > (_page+1)*100 ? GestureDetector(
          onTap: () {
            showMore();
          },
          child: Padding(
            padding: EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(appStrings(context).showMore(nbImages-((_page+1)*100)), style: TextStyle(fontSize: 14, color: _theme.disabledColor)),
              ],
            ),
          ),
        ) : Center(),
        Center(
          child: Container(
            padding: EdgeInsets.all(10),
            child: Text(appStrings(context).imageCount(nbImages), style: TextStyle(fontSize: 20, color: _theme.textTheme.bodyText2.color, fontWeight: FontWeight.w300)),
          ),
        )
      ],
    );
  }

  Widget get _createBottomBar {
    ThemeData _theme = Theme.of(context);
    return BottomNavigationBar(
      onTap: (index) async {
        if(_selectedItems.length > 0) {
          switch (index) {
            case 0:
              _onEditSelection();
              break;
            case 1:
              _onDownloadSelection();
              break;
            case 2:
              _onMoveCopySelection();
              break;
            case 3:
              _onDeleteSelection();
              break;
            default:
              break;
          }
        }
      },
      items: <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.edit, color: _theme.iconTheme.color),
          label: appStrings(context).imageOptions_edit,
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.download_rounded, color: _theme.iconTheme.color),
          label: appStrings(context).imageOptions_download,
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.drive_file_move, color: _theme.iconTheme.color),
          label: appStrings(context).moveImage_title,
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.delete_outline, color: _theme.errorColor),
          label: appStrings(context).deleteImage_delete,
        ),
      ],
      backgroundColor: _theme.scaffoldBackgroundColor,
      type: BottomNavigationBarType.fixed,
      selectedFontSize: 14,
      unselectedFontSize: 14,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      currentIndex: 0,
    );
  }

  Widget get _createFloatingActionButton {
    final uploadStatusProvider = Provider.of<UploadStatusNotifier>(context);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Stack(
        children: <Widget>[
          widget.isAdmin || _canUpload ? Align(
            alignment: Alignment.bottomRight,
            child: _createUploadActionButton,
          ) : const SizedBox(),
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              margin: EdgeInsets.only(bottom: 0, right: widget.isAdmin || _canUpload ? 70 : 0),
              child: FloatingActionButton(
                backgroundColor: Color(0xff868686),
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: uploadStatusProvider.status ?
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 55,
                          width: 55,
                          child: CircularProgressIndicator(
                            strokeWidth: 5,
                            value: uploadStatusProvider.progress,
                          ),
                        ),
                        Text("${uploadStatusProvider.getRemaining()}",
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ) :
                    Icon(Icons.home, color: Colors.grey.shade200, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
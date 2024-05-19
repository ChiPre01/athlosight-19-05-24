import 'package:athlosight/screens/comment_screen.dart';
import 'package:athlosight/screens/full_screen_myprofile.dart';
import 'package:athlosight/widgets/video_player_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_share/flutter_share.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId, });

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  String username = ''; // Add this line
  String profileImageUrl = ''; // Add this line
  bool _isFollowing = false;
  int _followersCount = 0;
  int _followingCount = 0;
   NativeAd? _nativeAd;
  bool _nativeAdIsLoaded = false;


 // Add the following line
  final String _adUnitId = 'ca-app-pub-1798341219433190/4386798498'; // replace with your actual ad unit ID

  @override
  void initState() {
    super.initState();
        _fetchUserData(); // Fetch user data to update the username
    _checkIfFollowing();
    _fetchFollowersCount();
    _fetchFollowingCount();
        _loadAd();
  }
    /// Loads a native ad.
  void _loadAd() {
    setState(() {
      _nativeAdIsLoaded = false;
    });

    _nativeAd = NativeAd(
        adUnitId: _adUnitId,
        factoryId: 'adFactoryExample',
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            // ignore: avoid_print
            print('$NativeAd loaded.');
            setState(() {
              _nativeAdIsLoaded = true;
            });
          },
          onAdFailedToLoad: (ad, error) {
            // ignore: avoid_print
            print('$NativeAd failedToLoad: $error');
            ad.dispose();
          },
          onAdClicked: (ad) {},
          onAdImpression: (ad) {},
          onAdClosed: (ad) {},
          onAdOpened: (ad) {},
          onAdWillDismissScreen: (ad) {},
          onPaidEvent: (ad, valueMicros, precision, currencyCode) {},
        ),
        request: const AdRequest(),
    )..load();
  }


  Future<void> _checkIfFollowing() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
       print('Current User ID: ${currentUser.uid}');
  print('Target User ID: ${widget.userId}');
      final followingSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(widget.userId)
          .get();
      setState(() {
        _isFollowing = followingSnapshot.exists;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
       print('Current User ID: ${currentUser.uid}');
  print('Target User ID: ${widget.userId}');
      final followingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(widget.userId);

      final followerRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('followers')
          .doc(currentUser.uid);

      if (_isFollowing) {
        // Unfollow the user
        await followingRef.delete();
        await followerRef.delete();
        setState(() {
          _followersCount -= 1;
        });
      } else try {
  await followingRef.set({});
  await followerRef.set({});
} catch (error) {
  print("Error toggling follow: $error");
}


      setState(() {
        _isFollowing = !_isFollowing;
      });
    }
  }
  
  Future<DocumentSnapshot> _fetchUserData() async {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(widget.userId)
      .get();
}

Future<void> _toggleLike(String postId, bool isLiked) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    // Update the like count and isLiked for the post
    await postRef.update({
      'likesCount': isLiked ? FieldValue.increment(-1) : FieldValue.increment(1),
      'isLiked': !isLiked,
    });

    if (!isLiked) {
      // If the post is being liked, fetch the usernames of users who liked the post
      final likedUsersSnapshot = await postRef.collection('likes').get();
      final likedUserIds = likedUsersSnapshot.docs.map((doc) => doc.id).toList();

      // Fetch user data for each user who liked the post
      final likedUsernames = await Future.wait(likedUserIds.map((userId) async {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        return userDoc.exists ? userDoc.data()!['username'] : null;
      }));

      // Remove null values from the list of usernames
      likedUsernames.removeWhere((username) => username == null);

      // Show dialog with the list of usernames
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Users who liked the post'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: likedUsernames.map((username) => Text(username)).toList(),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Close'),
              ),
            ],
          );
        },
      );
    }
  }
}



  Future<void> _fetchFollowersCount() async {
    final followersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('followers')
        .get();
    setState(() {
      _followersCount = followersSnapshot.size;
    });
  }

  Future<void> _fetchFollowingCount() async {
    final followingSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('following')
        .get();
    setState(() {
      _followingCount = followingSnapshot.size;
    });
  }
    
void _saveChatToFirestore(String otherUserId, String otherUsername, String otherProfileImageUrl) {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;

  final currentUserData = {
    'userId': currentUser.uid,
    'username': currentUser.displayName ?? '',
    'profileImageUrl': currentUser.photoURL ?? '',
  };

  final otherUserData = {
    'userId': otherUserId,
    'username': otherUsername,
    'profileImageUrl': otherProfileImageUrl,
  };

  // Save the chat data for the current user
  FirebaseFirestore.instance
      .collection('users')
      .doc(currentUser.uid)
      .collection('chats')
      .doc(otherUserId)
      .set(otherUserData);

  // Save the chat data for the other user
  FirebaseFirestore.instance
      .collection('users')
      .doc(otherUserId)
      .collection('chats')
      .doc(currentUser.uid)
      .set(currentUserData);
}

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:AppBar(
  title: const Text('Profile'),
  leading: IconButton(
    icon: Icon(Icons.arrow_back, color: Colors.deepPurple),
    onPressed: () {
      Navigator.pop(context); // Navigate to the previous screen
    },
  ),
),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<DocumentSnapshot>(
              future: _fetchUserData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting ||
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                 username = userData?['username'] ?? '';
                 profileImageUrl = userData?['profileImageUrl'] ?? '';
                final country = userData?['country'] ?? '';
                final age = userData?['age'] ?? '';
                  final fullName = userData?['fullName'] ?? '';
    final playingPosition = userData?['playingPosition'] ?? '';
        final gender = userData?['gender'] ?? '';
    final currentTeam = userData?['currentTeam'] ?? '';
    final playingCareer = userData?['playingCareer'] ?? '';
    final styleOfPlay = userData?['styleOfPlay'] ?? '';
    final phoneNumber = userData?['phoneNumber'] ?? '';

     
            
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullScreenImageProfile(
                                imageUrl: profileImageUrl,
                              ),
                            ),
                          );
                        },
                        child: Hero(
                          tag: 'fullscreen-image',
                          child: CircleAvatar(
                            backgroundImage: NetworkImage(profileImageUrl),
                            radius: 60,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Username: $username',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Country: $country',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Age: $age',
                        style: const TextStyle(fontSize: 18),
                      ),
                        const SizedBox(height: 8),
                      Text(
                        'Full Name: $fullName',
                        style: const TextStyle(fontSize: 18),
                      ),
                        const SizedBox(height: 8),
                      Text(
                        'Playing Position: $playingPosition',
                        style: const TextStyle(fontSize: 18),
                      ),
                        const SizedBox(height: 8),
                         Text(
                        'Gender: $gender',
                        style: const TextStyle(fontSize: 18),
                      ),
                        const SizedBox(height: 8),
                      Text(
                        'Current Team: $currentTeam',
                        style: const TextStyle(fontSize: 18),
                      ),
                        const SizedBox(height: 8),
                      Text(
                        'Playing Career: $playingCareer',
                        style: const TextStyle(fontSize: 18),
                      ),
                        const SizedBox(height: 8),
                      Text(
                        'Style of Play: $styleOfPlay',
                        style: const TextStyle(fontSize: 18),
                      ),
                       Text(
                        'Phone Number: $phoneNumber',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Fanbase: $_followersCount',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Fanning: $_followingCount',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _toggleFollow,
                  child: Text(_isFollowing ? 'Unfan -' : 'Fan +'),
                ),
              
              ],
            ),
            const Text(
              'Posts',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('posts')
      .where('uid', isEqualTo: widget.userId)
      .snapshots(),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final posts = snapshot.data!.docs;
                 
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index].data() as Map<String, dynamic>;
          final caption = post['caption'] as String? ?? '';
          final videoUrl = post['videoUrl'] as String? ?? '';
          final timestampStr = post['timestamp'] as String;
          final timestampMillis = int.tryParse(timestampStr) ?? 0;
          final timestamp =
              DateTime.fromMillisecondsSinceEpoch(timestampMillis);
          final formattedTimestamp =
              DateFormat.yMMMMd().add_jm().format(timestamp);
          final isLiked = post['isLiked'] ?? false;
          final likesCount = post['likesCount'] ?? 0;
                    final imageUrl = post['imageUrl'] as String? ?? '';

           Widget mediaWidget;
          if (videoUrl.isNotEmpty) {
            mediaWidget = AspectRatio(
              aspectRatio: 10 / 16,
              child: VideoPlayerWidget(videoUrl: videoUrl),
            );
          } else if (imageUrl.isNotEmpty) {
            mediaWidget = Image.network(imageUrl);
          } else {
            mediaWidget = const SizedBox(); // If neither image nor video is available
          }

          // Build the post widget
          Widget postWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  caption,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            mediaWidget,
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  formattedTimestamp,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      // Handle like functionality
                      _toggleLike(posts[index].id, isLiked);
                    },
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.deepPurpleAccent : null,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
        // Handle like count click
        _toggleLike(posts[index].id, isLiked);
      },
                    child: Column(
                      children: [
                        Text(
                          '$likesCount',
                          style: const TextStyle(fontSize: 16),
                        ),
                        Text(
                          'Likes',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Handle comment functionality
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CommentScreen(
                            postId: posts[index].id,
                            currentUsername: '',
                            profileImageUrl: '',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.comment),
                  ),
                  FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(posts[index].id)
                        .collection('comments')
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                              ConnectionState.waiting ||
                          !snapshot.hasData) {
                        return const SizedBox();
                      }

                      final commentsCount =
                          snapshot.data!.docs.length;

                      return Column(
                        children: [
                          Text(
                            '$commentsCount',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Text(
                            'Comments',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      );
                    },
                  ),
                  IconButton(
                    onPressed: () async {
                      // Handle share functionality
                      final String textToShare =
                          'Check out this post: $caption\n\nVideo: $videoUrl';

                      // Share the post using the flutter_share package
                      await FlutterShare.share(
                        title: 'Shared Post',
                        text: textToShare,
                        chooserTitle: 'Share',
                      );
                    },
                    icon: const Icon(Icons.share),
                  ),
                ],
              ),
              const Divider(),
            ],
          );

          if (index == 0 && _nativeAdIsLoaded && _nativeAd != null) {
            // If it's the first post, insert the native ad
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                postWidget, // Post widget
                SizedBox(
                  height: 300, // Adjust the height as needed
                  width: MediaQuery.of(context).size.width,
                  child: AdWidget(ad: _nativeAd!), // Native ad widget
                ),
              ],
            );
          } else {
            // Otherwise, just return the post widget
            return postWidget;
          }
        },
      );
    }
    return const SizedBox(); // Return an empty container if no data
  },
),

          ],
        ),
      ),
    );
  }
}



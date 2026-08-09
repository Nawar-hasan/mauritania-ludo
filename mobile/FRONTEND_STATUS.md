# Frontend implementation status

## Implemented as dedicated screens

1. Splash
2. Onboarding (3 slides)
3. Language selection
4. Login
5. Registration
6. OTP verification
7. Forgot password
8. Reset password
9. Reset success
10. Terms and policies
11. Main shell navigation
12. Home dashboard
13. Notifications
14. Game-mode selection
15. Player-count selection
16. Rules selection: Classic / Quick / Master
17. Wager selection
18. Wager confirmation
19. Matchmaking
20. Opponent found
21. Private-room creation
22. Join room by code
23. Room preview
24. Waiting room
25. Two-player Ludo board
26. Four-player Ludo board
27. Turn timer and automatic actions
28. Quick chat sheet
29. Gifts sheet
30. Casual skills sheet
31. Match rules sheet
32. Forfeit confirmation
33. Victory result
34. Defeat result
35. Forfeit result
36. Timeout result
37. Cancelled/refunded result
38. Match details and dice log
39. Wallet dashboard
40. Deposit amount and method
41. Transfer account and QR
42. Receipt submission
43. Deposit submitted
44. Withdrawal form
45. Withdrawal review and OTP
46. Withdrawal submitted
47. Transaction history
48. Transaction details
49. Store: coins
50. Store: gems
51. Store: casual skills
52. Store: dice
53. Store: frames
54. Purchase confirmation sheet
55. Purchase success
56. Tournament list
57. Tournament details
58. Bracket
59. Leaderboard
60. Featured social rooms
61. My rooms empty state
62. Video rooms empty state
63. Create voice room
64. Voice room
65. Voice chat and gifts
66. Profile
67. Avatar options sheet
68. Edit profile
69. Statistics
70. Match history
71. Inventory
72. Achievements
73. Referrals
74. Account settings
75. Privacy settings
76. Sound and vibration settings
77. Support
78. About
79. Full screen catalog

## Mock functionality included

- Local account flow navigation.
- Arabic/English direction switching.
- Mock balances and transactions.
- Local wager locking, settlement and refund.
- Matchmaking countdown.
- Private-room waiting simulation.
- Local dice rolling.
- Roll timer and move timer.
- Automatic roll/move when time expires.
- Timeout after repeated inactivity.
- Local Ludo-board rendering using CustomPainter.
- Mock deposit and withdrawal flows.
- Store selection and purchase flow.
- Tournament and social-room navigation.

## Backend responsibilities reserved for the next phase

- Authentication, OTP and sessions.
- User profiles and media upload.
- Authoritative dice RNG.
- Full Ludo rules engine and realtime synchronization.
- Matchmaking and WebSocket game rooms.
- Wallet ledger and payment verification.
- Wager escrow and settlement.
- KYC, age verification and country compliance.
- Voice/video infrastructure.
- Push notifications, moderation and support tickets.

import 'package:flutter/material.dart';

class FootballCalendarScreen extends StatelessWidget {
  const FootballCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          "AGENDA DU SPECTACLE",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildMatchCard(
                  "ELITE ONE - J12",
                  "Coton Sport",
                  "Canon Yaoundé",
                  "15:30",
                  "Stade de Garoua",
                  true,
                ),
                _buildMatchCard(
                  "ELITE ONE - J12",
                  "Union Douala",
                  "Bamboutos FC",
                  "17:00",
                  "Stade de Japoma",
                  false,
                ),
                _buildMatchCard(
                  "COUPE DU CAMEROUN",
                  "Aigle Royal",
                  "Stade Renard",
                  "Dimanche",
                  "Stade de Bafoussam",
                  false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          bool isSelected = index == 1;
          return Container(
            width: 70,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? Colors.green : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "DEC",
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white54,
                    fontSize: 10,
                  ),
                ),
                Text(
                  "${24 + index}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMatchCard(
    String league,
    String team1,
    String team2,
    String time,
    String stadium,
    bool isBigMatch,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isBigMatch ? Colors.amber.withOpacity(0.3) : Colors.white10,
        ),
        image: isBigMatch
            ? DecorationImage(
                image: const NetworkImage(
                  "https://www.transparenttextures.com/patterns/carbon-fibre.png",
                ),
                opacity: 0.1,
              )
            : null,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                league,
                style: TextStyle(
                  color: isBigMatch ? Colors.amber : Colors.greenAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(
                Icons.notifications_none,
                color: Colors.white24,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _teamInCalendar(team1),
              Column(
                children: [
                  Text(
                    time,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  const Text(
                    "VS",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              _teamInCalendar(team2),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, color: Colors.white38, size: 12),
              const SizedBox(width: 5),
              Text(
                stadium,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _teamInCalendar(String name) {
    return Column(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: Colors.white.withOpacity(0.1),
          child: const Icon(Icons.sports_soccer, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

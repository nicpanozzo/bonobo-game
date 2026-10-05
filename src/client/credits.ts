export interface Credit {
  name: string;
  role: string;
  contribution: string;
}

export const CREDITS: Credit[] = [
  {
    name: "Nicola Panozzo",
    role: "Maintainer / Developer",
    contribution: "Project creation, game code and multiplayer foundation",
  },
  {
    name: "Claude",
    role: "AI-assisted contribution",
    contribution: "Development guidance and project rules",
  },
  {
    name: "Samuel Eze Anayo",
    role: "Contributor",
    contribution: "Credits screen implementation",
  },
];

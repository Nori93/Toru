import os
import asyncio

import discord

from brain_api import ask_toru_with_tools


DISCORD_TOKEN = os.getenv("DISCORD_TOKEN")


intents = discord.Intents.default()
intents.message_content = True  # needed to read normal text messages


class ToruClient(discord.Client):
    async def on_ready(self) -> None:
        print(f"Logged in as {self.user} (ID: {self.user.id})")
        print("Toru Discord bot online!")

    async def on_message(self, message: discord.Message) -> None:
        # Ignore our own messages and other bots
        if message.author.bot:
            return

        # Simple command prefix: "!toru <question>"
        prefix = "!toru "
        if not message.content.startswith(prefix):
            return

        question = message.content[len(prefix) :].strip()
        if not question:
            await message.reply("What do you want to ask Toru?")
            return

        # Indicate that Toru is thinking
        async with message.channel.typing():
            # ask_toru_with_tools is synchronous; run it in a thread pool
            loop = asyncio.get_running_loop()
            answer: str = await loop.run_in_executor(
                None, ask_toru_with_tools, question
            )

        # Discord messages are limited; be safe and truncate if necessary
        if len(answer) > 1900:
            answer = answer[:1900] + "..."

        await message.reply(answer)


def main() -> None:
    if not DISCORD_TOKEN:
        raise RuntimeError(
            "DISCORD_TOKEN environment variable is not set. "
            "Create a bot in the Discord Developer Portal, copy its token, "
            "and set DISCORD_TOKEN before running this script."
        )

    client = ToruClient(intents=intents)
    client.run(DISCORD_TOKEN)


if __name__ == "__main__":
    main()

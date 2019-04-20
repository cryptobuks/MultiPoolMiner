namespace MonoTorrent.Client.PieceWriters
{
    using System;
    using System.Collections.Generic;
    using System.Text;
    using MonoTorrent.Common;

    public interface IPieceWriter
    {
        void Close(TorrentFile file);
        bool Exists(TorrentFile file);
        void Flush(TorrentFile file);
        int Read(TorrentFile file, long offset, byte[] buffer, int bufferOffset, int count);
        void Write(TorrentFile file, long offset, byte[] buffer, int bufferOffset, int count);
    }
}

using Microsoft.EntityFrameworkCore;
using PublisherService.Models;

namespace PublisherService.Data
{
    public class MessageDbContext : DbContext
    {
        public MessageDbContext(DbContextOptions<MessageDbContext> options) : base(options)
        {
        }

        public DbSet<Message> Messages { get; set; } = null!;

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<Message>(entity =>
            {
                entity.ToTable("Messages");
                entity.HasKey(e => e.MessageId);
                entity.Property(e => e.MonitorId).IsRequired().HasMaxLength(50);
                entity.Property(e => e.MessageContent).IsRequired();
                entity.Property(e => e.Status).IsRequired().HasMaxLength(20);
                entity.Property(e => e.CreatedDate).IsRequired();
            });
        }

        public async Task<List<Message>> GetPendingMessagesAsync(int batchSize, CancellationToken cancellationToken)
        {
            var result = await Messages
                .FromSqlRaw("EXEC dbo.GetPendingMessages @p0", batchSize)
                .ToListAsync(cancellationToken);

            return result;
        }

        public async Task<int> UpdateMessageStatusAsync(
            long messageId,
            string status,
            string? errorMessage,
            bool incrementRetryCount,
            CancellationToken cancellationToken)
        {
            var incrementParam = incrementRetryCount ? 1 : 0;

            // Use ExecuteSqlInterpolatedAsync to properly handle null parameters
            var result = await Database.ExecuteSqlInterpolatedAsync(
                $"EXEC dbo.UpdateMessageStatus {messageId}, {status}, {errorMessage}, {incrementParam}",
                cancellationToken);

            return result;
        }
    }
}
